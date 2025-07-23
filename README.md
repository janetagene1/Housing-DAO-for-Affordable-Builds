# 🏘️ Housing DAO for Affordable Builds

A decentralized autonomous organization (DAO) smart contract that empowers communities to collectively fund and manage affordable housing projects through transparent governance and milestone-based fund distribution.

## 🌟 Overview

The Housing DAO enables community members to pool resources, vote on housing proposals, and track construction progress through verified milestones. This approach decentralizes housing development decisions and promotes affordable living spaces.

## ✨ Features

- 💰 **Community Fund Pool**: Members contribute STX tokens to build a collective fund
- 🗳️ **Democratic Voting**: Members vote on housing proposals and project decisions  
- 🏗️ **Milestone-Based Releases**: Funds are released in phases based on verified construction milestones
- 📋 **Project Management**: Track projects from proposal to completion
- ✅ **Verification System**: Community members verify milestone completion
- 🏠 **Housing Projects**: Create and manage affordable housing developments

## 🚀 Quick Start

### Join the DAO

```clarity
(contract-call? .housing-dao join-dao u1000000) ;; Contribute 1 STX
```

### Create a Housing Proposal

```clarity
(contract-call? .housing-dao create-proposal 
  "Affordable Housing Complex A" 
  "50-unit affordable housing project in downtown area with community garden"
  "residential"
  u50000000) ;; Request 50 STX
```

### Vote on Proposals

```clarity
(contract-call? .housing-dao vote-on-proposal u1 true) ;; Vote YES on proposal #1
```

### Execute Approved Proposals

```clarity
(contract-call? .housing-dao execute-proposal u1)
```

## 📊 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `join-dao` | Join the DAO by contributing STX tokens |
| `create-proposal` | Submit a new housing project proposal |
| `vote-on-proposal` | Vote for or against a proposal |
| `execute-proposal` | Execute an approved proposal after voting period |
| `create-housing-project` | Create a project from approved proposal |
| `add-milestone` | Add construction milestones (contractor only) |
| `verify-milestone` | Verify milestone completion (DAO members) |
| `release-milestone-funds` | Release funds for verified milestones |
| `update-project-status` | Update project status (contractor only) |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-dao-fund` | Get total DAO fund amount |
| `get-member-contribution` | Get member's total contribution |
| `get-proposal` | Get proposal details |
| `get-housing-project` | Get project details |
| `get-milestone` | Get milestone information |
| `is-dao-member` | Check if address is DAO member |

## 🏗️ Project Lifecycle

1. **💡 Proposal**: Community member creates housing proposal
2. **🗳️ Voting**: DAO members vote during voting period (1008 blocks)
3. **✅ Execution**: Approved proposals get executed and funds allocated
4. **🏠 Project Creation**: Housing project is created with contractor assignment
5. **📋 Milestones**: Contractor adds construction milestones
6. **✔️ Verification**: DAO members verify completed milestones
7. **💰 Fund Release**: Verified milestone funds are released to contractor
8. **🎉 Completion**: Project status updated throughout construction

## 🔧 Configuration

- **Voting Period**: 1008 blocks (~1 week)
- **Minimum Proposal**: 1,000,000 microSTX (1 STX)
- **Milestone Verification**: Requires DAO member verification

## 🛡️ Security Features

- Only DAO members can vote and verify milestones
- Proposals require minimum funding threshold
- Milestone funds only released after verification
- Contractor authorization for project updates
- Immutable voting records

## 📝 Usage Examples

### Complete Workflow Example

```clarity
;; 1. Join the DAO
(contract-call? .housing-dao join-dao u5000000)

;; 2. Create proposal  
(contract-call? .housing-dao create-proposal 
  "Green Apartments" 
  "Eco-friendly 20-unit complex with solar panels"
  "sustainable"
  u30000000)

;; 3. Vote on proposal
(contract-call? .housing-dao vote-on-proposal u1 true)

;; 4. Execute after voting period
(contract-call? .housing-dao execute-proposal u1)

;; 5. Create project
(contract-call? .housing-dao create-housing-project 
  u1 
  "Green Apartments Phase 1"
  "123 Eco Street, Green City"
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)

;; 6. Add milestone (as contractor)
(contract-call? .housing-dao add-milestone 
  u1 
  "Foundation and site preparation completed"
  u10000000)

;; 7. Verify milestone (as DAO member)
(contract-call? .housing-dao verify-milestone u1 u1)

;; 8. Release funds
(contract-call? .housing-dao release-milestone-funds u1 u1)
```

## 🎯 Project Status Values

- `"planning"` - Project in planning phase
- `"construction"` - Active construction
- `"completed"` - Project finished
- `"on-hold"` - Temporarily suspended

## 🔍 Querying Data

```clarity
;; Check DAO fund total
(contract-call? .housing-dao get-dao-fund)

;; Check if address is member
(contract-call? .housing-dao is-dao-member 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)

;; Get proposal details
(contract-call? .housing-dao get-proposal u1)

;; Get project status
(contract-call? .housing-dao get-housing-project u1)
```

## 🤝 Contributing

This is a community-driven project. All housing decisions are made collectively by DAO members through transparent voting processes.

## 📄 License

Open source - build affordable housing together! 🏠✨
