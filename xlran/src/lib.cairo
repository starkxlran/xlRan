use starknet::ContractAddress;

#[starknet::interface]
pub trait Ixlran<TContractState> {
    fn register_dao_amount(ref self: TContractState, stake_amount: u64);
    fn register_lawyer(ref self: TContractState, ipfs_hash: ByteArray) -> ContractAddress;
    fn register_case(
        ref self: TContractState,
        case_ipfs_hash: ByteArray,
        case_pred: bool,
        reputation_staked: u64,
        case_deadline: u64,
        case_pred_settlment: u64
    ) -> u64;
    fn ban_lawyer(ref self: TContractState, lawyer_address: ContractAddress);
    fn vote_lawyer(ref self: TContractState, lawyer_address: ContractAddress);
    fn approve_lawyer(ref self: TContractState, lawyer_address: ContractAddress);
    fn unstake_dao(ref self: TContractState) -> u64;
    fn mark_case_resolved(ref self: TContractState, case_id: u64, case_won: bool, case_settlment: u64) -> bool;
    fn get_lawyer_info(self: @TContractState, lawyer_address: ContractAddress) -> (ByteArray, bool, bool, u64);
    fn read_case(self: @TContractState, case_id: u64) -> (ContractAddress, ByteArray, u8);
    fn vote_dao_fees(ref self: TContractState, voted_dao_fee_state: u8);
    fn declare_new_dao_fee(ref self: TContractState, declared_new_fee: u8) -> u8;
    fn unvote_dao_fees(ref self: TContractState);
    fn vote_oracle(ref self: TContractState, case_id: u64, oracle_addr: ContractAddress);
    fn get_dao_fees(self: @TContractState) -> u8;
    fn get_case_oracle(self: @TContractState, case_id: u64) -> ContractAddress;
    fn invest_in_case(ref self: TContractState, case_id: u64, invest_amount: u64) -> ContractAddress;
    fn get_contract_token_balance(self: @TContractState) -> u256;
}

#[starknet::contract]
mod xlran {
    use core::option::OptionTrait;
use core::traits::TryInto;
use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[storage]
    struct Storage {
        owner: ContractAddress,
        lawyers: LegacyMap::<ContractAddress, LawyerInfo>,
        cases: LegacyMap::<u64, Case>,
        dao_members: LegacyMap::<ContractAddress, Stake>,
        fee_votes: LegacyMap::<u8,u64>,
        dao_fee_votes: LegacyMap::<ContractAddress, u8>,
        oracle_votes: LegacyMap::<(ContractAddress,u64),u64>,
        lawyer_votes: LegacyMap::<(ContractAddress, ContractAddress), u64>,
        oracle_voter_votes: LegacyMap::<(ContractAddress, u64), u64>,   
        case_investors: LegacyMap::<(u64,ContractAddress), u64>,
        case_oracle: LegacyMap::<u64, CaseOracle>,
        total_stake: u64,
        case_id: u64,
        dao_fees: u8,
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        LawyerInfo: LawyerInfo,
        Case: Case,
        StakeEvent: StakeEvent,
        LawyerBanned: LawyerBanned,
        LawyerVoted: LawyerVoted,
        LawyerApproved: LawyerApproved,
        DaoMemberRemoved: DaoMemberRemoved,
        CaseResolved: CaseResolved,
        DaoFeesVote: DaoFeesVote,
        NewDaoFeeDeclared: NewDaoFeeDeclared,
        DaoFeesUnvoted: DaoFeesUnvoted,
        OracleVoted: OracleVoted,
        CaseInvested: CaseInvested,
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[derive(Drop, Serde, Clone, starknet::Store, starknet::Event)]
    struct LawyerInfo {
        #[key]
        ipfs_hash: ByteArray,
        approved: bool,
        banned: bool,
        votes: u64,
        case_count: u64,
        case_correctly_pred: u64,
        reputation: u64,
        reputation_points_available: u64,
        approve_deadline: u64
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Stake {
        stake_amount: u64,
    }

    #[derive(Drop, Serde, Clone, starknet::Store, starknet::Event)]
    struct Case {
        #[key]
        lawyer_address: ContractAddress,
        case_ipfs_hash: ByteArray,
        case_status: u8,
        created_at: u64,
        case_pred: bool,
        reputation_staked: u64,
        case_deadline: u64,
        case_pred_settlment: u64,
        case_investment: u64,
        case_act_settlment: u64
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct CaseOracle {
        oracle: ContractAddress,
        votes: u64
    }

    #[derive(Drop, starknet::Event)]
    struct StakeEvent {
        lawyer_address: ContractAddress,
        stake_amount: u64,
        at_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct LawyerBanned {
        lawyer_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct LawyerVoted {
        lawyer_address: ContractAddress,
        votes: u64
    }

    #[derive(Drop, starknet::Event)]
    struct LawyerApproved {
        lawyer_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct DaoMemberRemoved {
        dao_member: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CaseResolved {
        case_id: u64,
        lawyer: ContractAddress,
        case_won: bool,
        lawyer_pred: bool,
        case_settlment: u64
    }

    #[derive(Drop, starknet::Event)]
    struct DaoFeesVote {
        dao_member: ContractAddress,
        vote_amount: u64,
        ideal_state: u8
    }

    #[derive(Drop, starknet::Event)]
    struct NewDaoFeeDeclared {
        new_dao_fee: u8
    }

    #[derive(Drop, starknet::Event)]
    struct DaoFeesUnvoted {
        dao_fees_unvoted: u8,
        unvote_amount: u64,
        dao_member: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct OracleVoted {
        case_id: u64,
        oracle: ContractAddress,
        voter: ContractAddress,
        votes: u64,
        most_voted_oracle: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct OracleDeclared {
        case_id: u64,
        oracle_addr: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct CaseInvested {
        case_id: u64,
        investor: ContractAddress,
        amount: u64
    }

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.owner.write(get_caller_address());

        // Initialize ERC20
        let name = "xlran";
        let symbol = "XLR";
        let initial_supply = 1000000;
        self.erc20.initializer(name, symbol);
        self.erc20.mint(self.owner.read(), initial_supply);
    }


    #[abi(embed_v0)]
    impl xlran of super::Ixlran<ContractState> {
        fn register_dao_amount(ref self: ContractState, stake_amount: u64) {
            let caller_adrr = get_caller_address();
            let curr_timestamp = get_block_timestamp();
            assert!(self.dao_members.read(caller_adrr).stake_amount == 0, "You have already staked");

            let stake = Stake {
                stake_amount,
            };

            self.dao_members.write(caller_adrr, stake);
            self.total_stake.write(self.total_stake.read() + stake_amount);
            self.erc20.transfer(get_contract_address(),stake_amount.try_into().unwrap());
            self.emit(StakeEvent {
                lawyer_address: caller_adrr,
                stake_amount,
                at_time: curr_timestamp
            });
        }

        fn register_lawyer(ref self: ContractState, ipfs_hash: ByteArray) -> ContractAddress {
            let lawyer_address = get_caller_address();
            assert!(!self.lawyers.read(lawyer_address).banned, "Lawyer is banned from joining or performing any contract actions!");
            assert!(self.lawyers.read(lawyer_address).approve_deadline==0,"Lawyer already exists!");

            let thirty_days = 30*24*60*60;
            let lawyer = LawyerInfo {
                ipfs_hash: ipfs_hash.clone(),
                approved: false,
                banned: false,
                votes: 0,
                case_count: 0,
                case_correctly_pred: 0,
                reputation: 0,
                reputation_points_available: 100,
                approve_deadline: get_block_timestamp()+thirty_days
            };
            self.lawyers.write(lawyer_address, lawyer.clone());
            self.emit(lawyer);
            lawyer_address
        }

        fn register_case(
            ref self: ContractState,
            case_ipfs_hash: ByteArray,
            case_pred: bool,
            reputation_staked: u64,
            case_deadline: u64,
            case_pred_settlment: u64
        ) -> u64 {
            let lawyer_address = get_caller_address();
            let mut lawyer_info = self.lawyers.read(lawyer_address);

            assert!(lawyer_info.approved, "Lawyer not approved");
            assert!(!lawyer_info.banned, "Lawyer is banned from joining or performing any contract actions!");
            assert!(lawyer_info.reputation_points_available >= reputation_staked, "Not enough reputation stake left");
            assert!(get_block_timestamp() < case_deadline, "Case deadline has passed");

            lawyer_info.reputation_points_available -= reputation_staked;
            self.lawyers.write(lawyer_address, lawyer_info);

            let case_id = self.case_id.read();
            let case = Case {
                lawyer_address,
                case_ipfs_hash,
                case_status: 0,
                created_at: get_block_timestamp(),
                case_pred,
                reputation_staked,
                case_deadline,
                case_pred_settlment,
                case_investment: 0,
                case_act_settlment: 0
            };

            self.cases.write(case_id, case.clone());    
            self.case_id.write(case_id + 1);
            self.emit(case);
            case_id
        }

        fn ban_lawyer(ref self: ContractState, lawyer_address: ContractAddress) {
            assert!(get_caller_address() == self.owner.read(), "Only owner can ban lawyer");
            let mut lawyer_info = self.lawyers.read(lawyer_address);
            lawyer_info.banned = true;
            self.lawyers.write(lawyer_address, lawyer_info);
            self.emit(LawyerBanned { lawyer_address });
        }

        fn vote_lawyer(ref self: ContractState, lawyer_address: ContractAddress) {
            let caller_address = get_caller_address();
            let votes = self.dao_members.read(caller_address).stake_amount;
            let mut lawyer_info = self.lawyers.read(lawyer_address);
            assert!(!lawyer_info.banned, "Lawyer is banned from joining or performing any contract actions!");
            assert!(get_block_timestamp()<=lawyer_info.approve_deadline,"Lawyer approve deadline has passed");

            let mut voter_votes = self.lawyer_votes.read((caller_address, lawyer_address));
            assert!(voter_votes == 0, "You have already voted for this lawyer");
        
            lawyer_info.votes += votes;
            self.lawyers.write(lawyer_address, lawyer_info.clone());
            self.emit(LawyerVoted {
                lawyer_address,
                votes: lawyer_info.votes
            });
        }

        fn approve_lawyer(ref self: ContractState, lawyer_address: ContractAddress) {
            let votes = self.lawyers.read(lawyer_address).votes;
            assert!(votes >= self.total_stake.read() / 2, "Lawyer not approved");
            let mut lawyer_info = self.lawyers.read(lawyer_address);
            assert!(!lawyer_info.banned, "Lawyer is banned from joining or performing any contract actions!");
            assert!(get_block_timestamp()<=lawyer_info.approve_deadline,"Lawyer approve deadline has passed");
            lawyer_info.approved = true;
            self.lawyers.write(lawyer_address, lawyer_info);
            self.emit(LawyerApproved { lawyer_address });
        }

        fn unstake_dao(ref self: ContractState) -> u64 {
            let caller_address = get_caller_address();
            assert!(self.dao_fee_votes.read(caller_address)==0,"You have an active vote on dao fees, please unstake it to exit from the dao!");
            let stake = self.dao_members.read(caller_address);
            self.total_stake.write(self.total_stake.read() - stake.stake_amount);
            self.dao_members.write(caller_address, Stake { stake_amount: 0 });
            self.emit(DaoMemberRemoved { dao_member: caller_address });
            self.erc20.transfer(caller_address,stake.stake_amount.try_into().unwrap());
            return stake.stake_amount;
        }

        fn mark_case_resolved(ref self: ContractState, case_id: u64, case_won: bool, case_settlment: u64) -> bool{
            let lawyer = get_caller_address();
            let mut case = self.cases.read(case_id);

            assert!(case.lawyer_address == lawyer, "You are not the lawyer of this case");
            
            case.case_status = if case_won { 1 } else { 2 };
            case.case_act_settlment = case_settlment;
            self.cases.write(case_id, case.clone());

            let mut lawyer_info = self.lawyers.read(lawyer);
            assert!(!lawyer_info.banned, "Lawyer is banned from joining or performing any contract actions!");
            lawyer_info.case_count += 1;
            lawyer_info.reputation_points_available += case.reputation_staked;

            let oracle_result = case_won && case.case_pred_settlment == case_settlment && case.case_deadline <= get_block_timestamp();
            if case.case_pred == oracle_result {
                lawyer_info.case_correctly_pred += 1;
                lawyer_info.reputation += case.reputation_staked;
            } else {
                if(lawyer_info.reputation<case.reputation_staked){
                    lawyer_info.reputation = 0;
                }else{
                    lawyer_info.reputation -= case.reputation_staked;
                };
            }
            
            self.lawyers.write(lawyer, lawyer_info);
            self.emit(CaseResolved {
                case_id,
                lawyer,
                case_won,
                lawyer_pred: case.case_pred,
                case_settlment: case_settlment
            });
            return oracle_result;
        }

        fn vote_dao_fees(ref self: ContractState, voted_dao_fee_state: u8){
            let caller_address = get_caller_address();

            assert!(voted_dao_fee_state<30,"DAO fees can not include be over or equal to lawyer compensation");
            assert!(self.dao_fee_votes.read(caller_address)==0,"You have already voted for another dao fees, please unvote there to vote on this dao fee!");

            let votes = self.dao_members.read(caller_address).stake_amount;
            let curr_vote = self.fee_votes.read(voted_dao_fee_state);
            self.fee_votes.write(voted_dao_fee_state,votes+curr_vote);
            self.dao_fee_votes.write(caller_address,voted_dao_fee_state);
            self.emit( DaoFeesVote {dao_member: caller_address, ideal_state: voted_dao_fee_state, vote_amount: curr_vote});
        }

        fn unvote_dao_fees(ref self: ContractState){
            let caller_address = get_caller_address();
            let votes = self.dao_members.read(caller_address).stake_amount;

            let voted_on = self.dao_fee_votes.read(caller_address);
            self.dao_fee_votes.write(caller_address,0);
            
            let curr_fee_vote = self.fee_votes.read(voted_on);
            self.fee_votes.write(voted_on,curr_fee_vote-votes);
            self.emit(DaoFeesUnvoted{dao_fees_unvoted: voted_on, unvote_amount: votes, dao_member: caller_address});
        }

        fn declare_new_dao_fee(ref self: ContractState, declared_new_fee: u8) -> u8{
            assert!(self.fee_votes.read(declared_new_fee)>self.total_stake.read()/2,"Vote amount not enough to declare new dao fees");
            self.dao_fees.write(declared_new_fee);
            self.emit(NewDaoFeeDeclared{ new_dao_fee: declared_new_fee });
            return declared_new_fee;
        }

        fn vote_oracle(ref self: ContractState, case_id: u64, oracle_addr: ContractAddress){
            let caller_address = get_caller_address();
            let votes = self.dao_members.read(caller_address).stake_amount;
            let case = self.cases.read(case_id);

            assert!(case.case_deadline>=get_block_timestamp(),"Case has already closed, can no longer vote on oracles for this case");
            // Add a new storage variable to track votes
            let voter_votes = self.oracle_voter_votes.read((caller_address, case_id));
            assert!(voter_votes == 0, "You have already voted for an oracle in this case");
        
            let key = (oracle_addr, case_id);
            let curr_oracle_vote = self.oracle_votes.read(key);
            let total_votes = curr_oracle_vote+votes;
            self.oracle_votes.write(key, total_votes);
            if(total_votes>self.case_oracle.read(case_id).votes){
                self.case_oracle.write(case_id,CaseOracle{
                    oracle: oracle_addr,
                    votes: total_votes
                });
            };
            self.emit(OracleVoted{
                case_id: case_id,
                oracle: oracle_addr,
                voter: caller_address,
                votes: votes,
                most_voted_oracle: self.case_oracle.read(case_id).oracle
            });
        }

        fn invest_in_case(ref self: ContractState, case_id: u64, invest_amount: u64) -> ContractAddress{
            let caller_address = get_caller_address();

            let mut case = self.cases.read(case_id);
            let curr_inv = case.case_investment;
            let new_inv = curr_inv+invest_amount;
            assert!(10*new_inv<=3*case.case_pred_settlment,"Can not invest over maximum comission");

            case.case_investment = new_inv;
            self.cases.write(case_id,case);

            let key = (case_id,caller_address);
            let curr_voter_inv = self.case_investors.read(key);
            self.case_investors.write(key,curr_voter_inv+invest_amount);
            self.erc20.transfer(caller_address,invest_amount.try_into().unwrap());
            self.emit(CaseInvested{
                case_id: case_id,
                investor: caller_address,
                amount: invest_amount
            });
            return caller_address;
        }


        fn get_lawyer_info(self: @ContractState, lawyer_address: ContractAddress) -> (ByteArray, bool, bool, u64) {
            let lawyer_info = self.lawyers.read(lawyer_address);
            (lawyer_info.ipfs_hash, lawyer_info.approved, lawyer_info.banned, lawyer_info.votes)
        }

        fn read_case(self: @ContractState, case_id: u64) -> (ContractAddress, ByteArray, u8) {
            let case = self.cases.read(case_id);
            (case.lawyer_address, case.case_ipfs_hash, case.case_status)
        }

        fn get_dao_fees(self: @ContractState) -> u8{
            self.dao_fees.read()
        }

        fn get_case_oracle(self: @ContractState, case_id: u64) -> ContractAddress{
            self.case_oracle.read(case_id).oracle
        }

        fn get_contract_token_balance(self: @ContractState) -> u256{
            self.erc20.balanceOf(self.owner.read())
        }
    }
}