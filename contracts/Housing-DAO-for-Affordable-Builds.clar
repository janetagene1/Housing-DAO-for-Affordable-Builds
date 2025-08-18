(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED u100)
(define-constant ERR_INVALID_PROPOSAL u101)
(define-constant ERR_ALREADY_VOTED u102)
(define-constant ERR_PROPOSAL_NOT_ACTIVE u103)
(define-constant ERR_INSUFFICIENT_FUNDS u104)
(define-constant ERR_MILESTONE_NOT_FOUND u105)
(define-constant ERR_ALREADY_VERIFIED u106)
(define-constant ERR_INVALID_MILESTONE u107)
(define-constant ERR_LOW_REPUTATION u108)
(define-constant VOTING_PERIOD u1008)
(define-constant MIN_PROPOSAL_THRESHOLD u1000000)
(define-constant BASE_REPUTATION_SCORE u1000)
(define-constant VOTE_PARTICIPATION_BONUS u10)
(define-constant PROPOSAL_APPROVED_BONUS u50)
(define-constant PROPOSAL_REJECTED_PENALTY u25)
(define-constant VERIFICATION_ACCURACY_BONUS u20)
(define-constant MIN_REPUTATION_FOR_PROPOSALS u800)

(define-data-var next-proposal-id uint u1)
(define-data-var next-project-id uint u1)
(define-data-var total-dao-fund uint u0)

(define-map dao-members principal uint)
(define-map member-contributions principal uint)
(define-map member-reputation principal {
    score: uint,
    total-votes: uint,
    successful-proposals: uint,
    failed-proposals: uint,
    verifications-made: uint
})

(define-map proposals uint {
    id: uint,
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    project-type: (string-ascii 50),
    requested-amount: uint,
    votes-for: uint,
    votes-against: uint,
    end-block: uint,
    executed: bool,
    approved: bool
})

(define-map proposal-votes {proposal-id: uint, voter: principal} bool)

(define-map housing-projects uint {
    id: uint,
    proposal-id: uint,
    name: (string-ascii 100),
    location: (string-ascii 200),
    total-budget: uint,
    funds-released: uint,
    contractor: principal,
    status: (string-ascii 20),
    created-at: uint
})

(define-map project-milestones {project-id: uint, milestone-id: uint} {
    description: (string-ascii 200),
    amount: uint,
    verified: bool,
    verifier: (optional principal),
    completed-at: (optional uint)
})

(define-map milestone-counter uint uint)

(define-public (join-dao (contribution uint))
    (let ((current-member (default-to u0 (map-get? dao-members tx-sender)))
          (current-contribution (default-to u0 (map-get? member-contributions tx-sender))))
        (asserts! (> contribution u0) (err ERR_INVALID_PROPOSAL))
        (try! (stx-transfer? contribution tx-sender (as-contract tx-sender)))
        (map-set dao-members tx-sender (+ current-member u1))
        (map-set member-contributions tx-sender (+ current-contribution contribution))
        (var-set total-dao-fund (+ (var-get total-dao-fund) contribution))
        (if (is-none (map-get? member-reputation tx-sender))
            (map-set member-reputation tx-sender {
                score: BASE_REPUTATION_SCORE,
                total-votes: u0,
                successful-proposals: u0,
                failed-proposals: u0,
                verifications-made: u0
            })
            true)
        (ok true)))

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) 
                               (project-type (string-ascii 50)) (requested-amount uint))
    (let ((proposal-id (var-get next-proposal-id))
          (member-status (default-to u0 (map-get? dao-members tx-sender)))
          (member-rep (unwrap! (map-get? member-reputation tx-sender) (err ERR_NOT_AUTHORIZED))))
        (asserts! (> member-status u0) (err ERR_NOT_AUTHORIZED))
        (asserts! (>= (get score member-rep) MIN_REPUTATION_FOR_PROPOSALS) (err ERR_LOW_REPUTATION))
        (asserts! (>= requested-amount MIN_PROPOSAL_THRESHOLD) (err ERR_INVALID_PROPOSAL))
        (asserts! (<= requested-amount (var-get total-dao-fund)) (err ERR_INSUFFICIENT_FUNDS))
        (map-set proposals proposal-id {
            id: proposal-id,
            proposer: tx-sender,
            title: title,
            description: description,
            project-type: project-type,
            requested-amount: requested-amount,
            votes-for: u0,
            votes-against: u0,
            end-block: (+ stacks-block-height VOTING_PERIOD),
            executed: false,
            approved: false
        })
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)))

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_INVALID_PROPOSAL)))
          (member-status (default-to u0 (map-get? dao-members tx-sender)))
          (vote-key {proposal-id: proposal-id, voter: tx-sender})
          (voter-rep (unwrap! (map-get? member-reputation tx-sender) (err ERR_NOT_AUTHORIZED)))
          (reputation-weight (if (> (get score voter-rep) u100) (/ (get score voter-rep) u100) u1)))
        (asserts! (> member-status u0) (err ERR_NOT_AUTHORIZED))
        (asserts! (< stacks-block-height (get end-block proposal)) (err ERR_PROPOSAL_NOT_ACTIVE))
        (asserts! (is-none (map-get? proposal-votes vote-key)) (err ERR_ALREADY_VOTED))
        (map-set proposal-votes vote-key vote-for)
        (map-set member-reputation tx-sender (merge voter-rep {
            total-votes: (+ (get total-votes voter-rep) u1),
            score: (+ (get score voter-rep) VOTE_PARTICIPATION_BONUS)
        }))
        (if vote-for
            (map-set proposals proposal-id (merge proposal {votes-for: (+ (get votes-for proposal) reputation-weight)}))
            (map-set proposals proposal-id (merge proposal {votes-against: (+ (get votes-against proposal) reputation-weight)})))
        (ok true)))

(define-public (execute-proposal (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_INVALID_PROPOSAL)))
          (proposer-rep (unwrap! (map-get? member-reputation (get proposer proposal)) (err ERR_INVALID_PROPOSAL))))
        (asserts! (>= stacks-block-height (get end-block proposal)) (err ERR_PROPOSAL_NOT_ACTIVE))
        (asserts! (not (get executed proposal)) (err ERR_INVALID_PROPOSAL))
        (let ((approved (> (get votes-for proposal) (get votes-against proposal))))
            (map-set proposals proposal-id (merge proposal {executed: true, approved: approved}))
            (if approved
                (begin
                    (map-set member-reputation (get proposer proposal) (merge proposer-rep {
                        successful-proposals: (+ (get successful-proposals proposer-rep) u1),
                        score: (+ (get score proposer-rep) PROPOSAL_APPROVED_BONUS)
                    }))
                    (var-set total-dao-fund (- (var-get total-dao-fund) (get requested-amount proposal)))
                    (ok true))
                (begin
                    (map-set member-reputation (get proposer proposal) (merge proposer-rep {
                        failed-proposals: (+ (get failed-proposals proposer-rep) u1),
                        score: (if (> (get score proposer-rep) PROPOSAL_REJECTED_PENALTY) 
                                  (- (get score proposer-rep) PROPOSAL_REJECTED_PENALTY) 
                                  u0)
                    }))
                    (ok false))))))

(define-public (create-housing-project (proposal-id uint) (name (string-ascii 100)) 
                                      (location (string-ascii 200)) (contractor principal))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR_INVALID_PROPOSAL)))
          (project-id (var-get next-project-id)))
        (asserts! (get approved proposal) (err ERR_NOT_AUTHORIZED))
        (asserts! (get executed proposal) (err ERR_NOT_AUTHORIZED))
        (map-set housing-projects project-id {
            id: project-id,
            proposal-id: proposal-id,
            name: name,
            location: location,
            total-budget: (get requested-amount proposal),
            funds-released: u0,
            contractor: contractor,
            status: "planning",
            created-at: stacks-block-height
        })
        (map-set milestone-counter project-id u0)
        (var-set next-project-id (+ project-id u1))
        (ok project-id)))

(define-public (add-milestone (project-id uint) (description (string-ascii 200)) (amount uint))
    (let ((project (unwrap! (map-get? housing-projects project-id) (err ERR_INVALID_PROPOSAL)))
          (milestone-count (default-to u0 (map-get? milestone-counter project-id)))
          (milestone-id (+ milestone-count u1)))
        (asserts! (is-eq tx-sender (get contractor project)) (err ERR_NOT_AUTHORIZED))
        (map-set project-milestones {project-id: project-id, milestone-id: milestone-id} {
            description: description,
            amount: amount,
            verified: false,
            verifier: none,
            completed-at: none
        })
        (map-set milestone-counter project-id milestone-id)
        (ok milestone-id)))

(define-public (verify-milestone (project-id uint) (milestone-id uint))
    (let ((project (unwrap! (map-get? housing-projects project-id) (err ERR_INVALID_PROPOSAL)))
          (milestone-key {project-id: project-id, milestone-id: milestone-id})
          (milestone (unwrap! (map-get? project-milestones milestone-key) (err ERR_MILESTONE_NOT_FOUND)))
          (member-status (default-to u0 (map-get? dao-members tx-sender)))
          (verifier-rep (unwrap! (map-get? member-reputation tx-sender) (err ERR_NOT_AUTHORIZED))))
        (asserts! (> member-status u0) (err ERR_NOT_AUTHORIZED))
        (asserts! (not (get verified milestone)) (err ERR_ALREADY_VERIFIED))
        (map-set project-milestones milestone-key (merge milestone {
            verified: true,
            verifier: (some tx-sender),
            completed-at: (some stacks-block-height)
        }))
        (map-set member-reputation tx-sender (merge verifier-rep {
            verifications-made: (+ (get verifications-made verifier-rep) u1),
            score: (+ (get score verifier-rep) VERIFICATION_ACCURACY_BONUS)
        }))
        (ok true)))

(define-public (release-milestone-funds (project-id uint) (milestone-id uint))
    (let ((project (unwrap! (map-get? housing-projects project-id) (err ERR_INVALID_PROPOSAL)))
          (milestone-key {project-id: project-id, milestone-id: milestone-id})
          (milestone (unwrap! (map-get? project-milestones milestone-key) (err ERR_MILESTONE_NOT_FOUND))))
        (asserts! (get verified milestone) (err ERR_INVALID_MILESTONE))
        (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get contractor project))))
        (map-set housing-projects project-id (merge project {
            funds-released: (+ (get funds-released project) (get amount milestone))
        }))
        (ok true)))

(define-public (update-project-status (project-id uint) (new-status (string-ascii 20)))
    (let ((project (unwrap! (map-get? housing-projects project-id) (err ERR_INVALID_PROPOSAL))))
        (asserts! (is-eq tx-sender (get contractor project)) (err ERR_NOT_AUTHORIZED))
        (map-set housing-projects project-id (merge project {status: new-status}))
        (ok true)))

(define-read-only (get-dao-fund)
    (ok (var-get total-dao-fund)))

(define-read-only (get-member-contribution (member principal))
    (ok (default-to u0 (map-get? member-contributions member))))

(define-read-only (get-proposal (proposal-id uint))
    (ok (map-get? proposals proposal-id)))

(define-read-only (get-housing-project (project-id uint))
    (ok (map-get? housing-projects project-id)))

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
    (ok (map-get? project-milestones {project-id: project-id, milestone-id: milestone-id})))

(define-read-only (get-user-vote (proposal-id uint) (voter principal))
    (ok (map-get? proposal-votes {proposal-id: proposal-id, voter: voter})))

(define-read-only (is-dao-member (member principal))
    (ok (> (default-to u0 (map-get? dao-members member)) u0)))

(define-read-only (get-next-proposal-id)
    (ok (var-get next-proposal-id)))

(define-read-only (get-next-project-id)
    (ok (var-get next-project-id)))

(define-read-only (get-member-reputation (member principal))
    (ok (map-get? member-reputation member)))

(define-read-only (get-reputation-score (member principal))
    (let ((reputation (map-get? member-reputation member)))
        (ok (if (is-some reputation) (get score (unwrap-panic reputation)) u0))))

(define-read-only (get-voting-weight (member principal))
    (let ((reputation (default-to {score: u0, total-votes: u0, successful-proposals: u0, failed-proposals: u0, verifications-made: u0} (map-get? member-reputation member))))
        (ok (if (> (get score reputation) u100) (/ (get score reputation) u100) u1))))
