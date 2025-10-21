Quality Rating System for Housing DAO

## Overview
This feature introduces a comprehensive contractor and project quality rating system to the Housing DAO platform. The system enables DAO members to rate completed housing projects across multiple quality dimensions, building contractor reputation scores and incentivizing excellence through rewards and bonuses.

## Technical Implementation

### Key Functions Added
- `rate-project`: Allows DAO members to rate completed projects on 5 quality dimensions (1-5 scale)
- `update-contractor-project-count`: Tracks contractor project completion statistics
- `get-quality-rating`: Retrieve specific quality rating details
- `get-contractor-ratings`: View comprehensive contractor rating statistics
- `get-contractor-average-rating`: Get contractor's average quality score
- `get-contractor-excellence-rate`: Calculate percentage of excellent ratings (5-star)
- `has-rated-project`: Check if a member has already rated a project

### Data Structures Added
- `quality-ratings` map: Stores detailed ratings with 5 quality dimensions
- `project-ratings` map: Tracks which members rated which projects (prevents double-rating)
- `contractor-ratings` map: Maintains aggregate contractor statistics and reputation

### Quality Dimensions
- Overall Quality (1-5)
- Materials Quality (1-5)
- Workmanship (1-5)
- Timeline Adherence (1-5)
- Communication (1-5)

### Incentive System
- **Rater Rewards**: 100 reputation points for submitting quality ratings
- **Excellence Bonus**: 200 reputation points for contractors receiving 5-star average ratings
- **Reputation Impact**: Quality scores affect contractor standing and future opportunities

## Testing & Validation
- ✅ Contract passes clarinet check
- ✅ All npm tests successful  
- ✅ CI/CD pipeline configured
- ✅ Clarity v3 compliant with proper error handling
- ✅ Independent feature with no cross-contract dependencies

## Benefits
1. **Quality Assurance**: Incentivizes high-quality construction work
2. **Transparency**: Public contractor ratings build trust
3. **DAO Governance**: Members participate in quality evaluation process
4. **Reputation System**: Creates accountability for contractors
5. **Data-Driven Decisions**: Historical quality data informs future project decisions
