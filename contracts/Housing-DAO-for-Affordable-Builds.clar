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
(define-constant ERR_DISPUTE_NOT_FOUND u109)
(define-constant ERR_DISPUTE_RESOLVED u110)
(define-constant ERR_CANNOT_DISPUTE_OWN u111)
(define-constant ERR_DISPUTE_PERIOD_ENDED u112)

;; Error constants for quality rating system
(define-constant ERR_PROJECT_NOT_COMPLETED u113)
(define-constant ERR_ALREADY_RATED u114)
(define-constant ERR_INVALID_RATING u115)
(define-constant ERR_RATING_NOT_FOUND u116)
(define-constant DISPUTE_VOTING_PERIOD u504)
(define-constant MIN_REPUTATION_FOR_DISPUTES u500)
(define-constant DISPUTE_FILING_COST u10000)

;; Quality rating system constants
(define-constant MIN_RATING u1)
(define-constant MAX_RATING u5)
(define-constant QUALITY_RATING_REWARD u100)
(define-constant EXCELLENCE_BONUS u200)

(define-data-var next-proposal-id uint u1)
(define-data-var next-project-id uint u1)
(define-data-var total-dao-fund uint u0)
(define-data-var next-dispute-id uint u1)
(define-data-var next-rating-id uint u1)

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

(define-map disputes uint {
    id: uint,
    disputer: principal,
    disputed-party: principal,
    project-id: uint,
    milestone-id: uint,
    reason: (string-ascii 300),
    evidence: (string-ascii 500),
    votes-for: uint,
    votes-against: uint,
    end-block: uint,
    resolved: bool,
    ruling: (optional bool),
    created-at: uint
})

(define-map dispute-votes {dispute-id: uint, voter: principal} bool)

;; Quality rating system maps
(define-map quality-ratings uint {
    id: uint,
    project-id: uint,
    rater: principal,
    contractor: principal,
    overall-quality: uint,
    materials-quality: uint,
    workmanship: uint,
    timeline-adherence: uint,
    communication: uint,
    comments: (string-ascii 300),
    created-at: uint
})

(define-map project-ratings {project-id: uint, rater: principal} uint)
(define-map contractor-ratings principal {
    total-ratings: uint,
    average-score: uint,
    excellence-count: uint,
    total-projects: uint
})

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

(define-public (file-dispute (disputed-party principal) (project-id uint) (milestone-id uint) 
                           (reason (string-ascii 300)) (evidence (string-ascii 500)))
    (let ((dispute-id (var-get next-dispute-id))
          (disputer-rep (unwrap! (map-get? member-reputation tx-sender) (err ERR_NOT_AUTHORIZED)))
          (member-status (default-to u0 (map-get? dao-members tx-sender)))
          (milestone-key {project-id: project-id, milestone-id: milestone-id})
          (milestone (unwrap! (map-get? project-milestones milestone-key) (err ERR_MILESTONE_NOT_FOUND))))
        (asserts! (> member-status u0) (err ERR_NOT_AUTHORIZED))
        (asserts! (>= (get score disputer-rep) MIN_REPUTATION_FOR_DISPUTES) (err ERR_LOW_REPUTATION))
        (asserts! (not (is-eq tx-sender disputed-party)) (err ERR_CANNOT_DISPUTE_OWN))
        (asserts! (get verified milestone) (err ERR_INVALID_MILESTONE))
        (try! (stx-transfer? DISPUTE_FILING_COST tx-sender (as-contract tx-sender)))
        (map-set disputes dispute-id {
            id: dispute-id,
            disputer: tx-sender,
            disputed-party: disputed-party,
            project-id: project-id,
            milestone-id: milestone-id,
            reason: reason,
            evidence: evidence,
            votes-for: u0,
            votes-against: u0,
            end-block: (+ stacks-block-height DISPUTE_VOTING_PERIOD),
            resolved: false,
            ruling: none,
            created-at: stacks-block-height
        })
        (var-set next-dispute-id (+ dispute-id u1))
        (ok dispute-id)))

(define-public (vote-on-dispute (dispute-id uint) (vote-for bool))
    (let ((dispute (unwrap! (map-get? disputes dispute-id) (err ERR_DISPUTE_NOT_FOUND)))
          (member-status (default-to u0 (map-get? dao-members tx-sender)))
          (vote-key {dispute-id: dispute-id, voter: tx-sender})
          (voter-rep (unwrap! (map-get? member-reputation tx-sender) (err ERR_NOT_AUTHORIZED)))
          (reputation-weight (if (> (get score voter-rep) u100) (/ (get score voter-rep) u100) u1)))
        (asserts! (> member-status u0) (err ERR_NOT_AUTHORIZED))
        (asserts! (< stacks-block-height (get end-block dispute)) (err ERR_DISPUTE_PERIOD_ENDED))
        (asserts! (not (get resolved dispute)) (err ERR_DISPUTE_RESOLVED))
        (asserts! (is-none (map-get? dispute-votes vote-key)) (err ERR_ALREADY_VOTED))
        (asserts! (not (is-eq tx-sender (get disputer dispute))) (err ERR_NOT_AUTHORIZED))
        (asserts! (not (is-eq tx-sender (get disputed-party dispute))) (err ERR_NOT_AUTHORIZED))
        (map-set dispute-votes vote-key vote-for)
        (if vote-for
            (map-set disputes dispute-id (merge dispute {votes-for: (+ (get votes-for dispute) reputation-weight)}))
            (map-set disputes dispute-id (merge dispute {votes-against: (+ (get votes-against dispute) reputation-weight)})))
        (ok true)))

(define-public (resolve-dispute (dispute-id uint))
    (let ((dispute (unwrap! (map-get? disputes dispute-id) (err ERR_DISPUTE_NOT_FOUND)))
          (disputed-party-rep (unwrap! (map-get? member-reputation (get disputed-party dispute)) (err ERR_NOT_AUTHORIZED)))
          (disputer-rep (unwrap! (map-get? member-reputation (get disputer dispute)) (err ERR_NOT_AUTHORIZED))))
        (asserts! (>= stacks-block-height (get end-block dispute)) (err ERR_DISPUTE_PERIOD_ENDED))
        (asserts! (not (get resolved dispute)) (err ERR_DISPUTE_RESOLVED))
        (let ((dispute-upheld (> (get votes-for dispute) (get votes-against dispute))))
            (map-set disputes dispute-id (merge dispute {resolved: true, ruling: (some dispute-upheld)}))
            (if dispute-upheld
                (begin
                    (map-set member-reputation (get disputed-party dispute) (merge disputed-party-rep {
                        score: (if (> (get score disputed-party-rep) u100) (- (get score disputed-party-rep) u100) u0)
                    }))
                    (try! (as-contract (stx-transfer? (/ DISPUTE_FILING_COST u2) tx-sender (get disputer dispute))))
                    (let ((milestone-key {project-id: (get project-id dispute), milestone-id: (get milestone-id dispute)}))
                        (map-set project-milestones milestone-key (merge (unwrap-panic (map-get? project-milestones milestone-key)) {
                            verified: false,
                            verifier: none
                        })))
                    (ok true))
                (begin
                    (map-set member-reputation (get disputer dispute) (merge disputer-rep {
                        score: (if (> (get score disputer-rep) u50) (- (get score disputer-rep) u50) u0)
                    }))
                    (ok false))))))

(define-read-only (get-dispute (dispute-id uint))
    (ok (map-get? disputes dispute-id)))

(define-read-only (get-dispute-vote (dispute-id uint) (voter principal))
    (ok (map-get? dispute-votes {dispute-id: dispute-id, voter: voter})))

(define-read-only (get-next-dispute-id)
    (ok (var-get next-dispute-id)))

;; Quality Rating System Functions
(define-public (rate-project (project-id uint) (overall-quality uint) (materials-quality uint) 
                           (workmanship uint) (timeline-adherence uint) (communication uint)
                           (comments (string-ascii 300)))
    (let ((project (unwrap! (map-get? housing-projects project-id) (err ERR_INVALID_PROPOSAL)))
          (rating-id (var-get next-rating-id))
          (member-status (default-to u0 (map-get? dao-members tx-sender)))
          (rating-key {project-id: project-id, rater: tx-sender}))
        ;; Validate inputs and permissions
        (asserts! (> member-status u0) (err ERR_NOT_AUTHORIZED))
        (asserts! (is-eq (get status project) "completed") (err ERR_PROJECT_NOT_COMPLETED))
        (asserts! (is-none (map-get? project-ratings rating-key)) (err ERR_ALREADY_RATED))
        (asserts! (and (>= overall-quality MIN_RATING) (<= overall-quality MAX_RATING)) (err ERR_INVALID_RATING))
        (asserts! (and (>= materials-quality MIN_RATING) (<= materials-quality MAX_RATING)) (err ERR_INVALID_RATING))
        (asserts! (and (>= workmanship MIN_RATING) (<= workmanship MAX_RATING)) (err ERR_INVALID_RATING))
        (asserts! (and (>= timeline-adherence MIN_RATING) (<= timeline-adherence MAX_RATING)) (err ERR_INVALID_RATING))
        (asserts! (and (>= communication MIN_RATING) (<= communication MAX_RATING)) (err ERR_INVALID_RATING))
        
        ;; Calculate average rating
        (let ((average-rating (/ (+ overall-quality materials-quality workmanship timeline-adherence communication) u5)))
            ;; Store the rating
            (map-set quality-ratings rating-id {
                id: rating-id,
                project-id: project-id,
                rater: tx-sender,
                contractor: (get contractor project),
                overall-quality: overall-quality,
                materials-quality: materials-quality,
                workmanship: workmanship,
                timeline-adherence: timeline-adherence,
                communication: communication,
                comments: comments,
                created-at: stacks-block-height
            })
            
            ;; Mark project as rated by this user
            (map-set project-ratings rating-key rating-id)
            
            ;; Increment rating ID
            (var-set next-rating-id (+ rating-id u1))
            
            ;; Update contractor rating statistics
            (let ((contractor (get contractor project))
                  (current-stats (default-to {total-ratings: u0, average-score: u0, excellence-count: u0, total-projects: u0} 
                                            (map-get? contractor-ratings contractor))))
                (let ((new-total-ratings (+ (get total-ratings current-stats) u1))
                      (new-average (/ (+ (* (get average-score current-stats) (get total-ratings current-stats)) average-rating) 
                                     new-total-ratings))
                      (new-excellence-count (if (>= average-rating u5) 
                                              (+ (get excellence-count current-stats) u1) 
                                              (get excellence-count current-stats))))
                    (map-set contractor-ratings contractor {
                        total-ratings: new-total-ratings,
                        average-score: new-average,
                        excellence-count: new-excellence-count,
                        total-projects: (get total-projects current-stats)
                    })))
            
            ;; Award reputation points to rater
            (let ((rater-rep (unwrap! (map-get? member-reputation tx-sender) (err ERR_NOT_AUTHORIZED))))
                (map-set member-reputation tx-sender (merge rater-rep {
                    score: (+ (get score rater-rep) QUALITY_RATING_REWARD)
                })))
            
            ;; Award excellence bonus to contractor if rating is 5
            (let ((contractor (get contractor project)))
                (if (>= average-rating u5)
                    (let ((contractor-rep (default-to {score: BASE_REPUTATION_SCORE, total-votes: u0, successful-proposals: u0, failed-proposals: u0, verifications-made: u0} 
                                                     (map-get? member-reputation contractor))))
                        (map-set member-reputation contractor (merge contractor-rep {
                            score: (+ (get score contractor-rep) EXCELLENCE_BONUS)
                        }))
                        (ok rating-id))
                    (ok rating-id))))))

(define-public (update-contractor-project-count (contractor principal))
    (let ((current-stats (default-to {total-ratings: u0, average-score: u0, excellence-count: u0, total-projects: u0} 
                                   (map-get? contractor-ratings contractor))))
        (map-set contractor-ratings contractor (merge current-stats {
            total-projects: (+ (get total-projects current-stats) u1)
        }))
        (ok true)))

;; Quality Rating Read-Only Functions
(define-read-only (get-quality-rating (rating-id uint))
    (ok (map-get? quality-ratings rating-id)))

(define-read-only (get-project-rating (project-id uint) (rater principal))
    (ok (map-get? project-ratings {project-id: project-id, rater: rater})))

(define-read-only (get-contractor-ratings (contractor principal))
    (ok (map-get? contractor-ratings contractor)))

(define-read-only (get-contractor-average-rating (contractor principal))
    (let ((ratings (map-get? contractor-ratings contractor)))
        (ok (if (is-some ratings) (get average-score (unwrap-panic ratings)) u0))))

(define-read-only (get-contractor-excellence-rate (contractor principal))
    (let ((ratings (map-get? contractor-ratings contractor)))
        (if (is-some ratings)
            (let ((stats (unwrap-panic ratings)))
                (if (> (get total-ratings stats) u0)
                    (ok (/ (* (get excellence-count stats) u100) (get total-ratings stats)))
                    (ok u0)))
            (ok u0))))

(define-read-only (get-next-rating-id)
    (ok (var-get next-rating-id)))

(define-read-only (has-rated-project (project-id uint) (rater principal))
    (ok (is-some (map-get? project-ratings {project-id: project-id, rater: rater}))))
