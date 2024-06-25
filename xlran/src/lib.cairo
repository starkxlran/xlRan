use starknet::ContractAddress;

#[starknet::interface]
trait Ixlran<TContractState> {
    fn register_dao_amount(ref self: TContractState, stake_amount: u64);
    fn register_lawyer(ref self: TContractState, lawyer_address: ContractAddress, ipfs_hash: ByteArray);
    fn register_case(ref self: TContractState, case_ipfs_hash: ByteArray, case_pred: bool, reputation_staked: u64);
    fn ban_lawyer(ref self: TContractState, lawyer_address: ContractAddress);
    fn vote_lawyer(ref self: TContractState, lawyer_address: ContractAddress);
    fn approve_lawyer(ref self: TContractState, lawyer_address: ContractAddress);
    fn unstake_dao(ref self: TContractState);
    fn mark_case_resolved(ref self: TContractState, case_id: u64, case_won: bool);
    fn get_lawyer_info(self: @TContractState, lawyer_address: ContractAddress) -> (ByteArray, bool, bool, u64);
    fn read_case(self: @TContractState, case_id: u64) -> (ContractAddress, ByteArray, u8);
}

#[starknet::contract]
mod xlran {
    use starknet::{ContractAddress, get_caller_address,get_block_timestamp};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        lawyers: LegacyMap::<ContractAddress, LawyerInfo>,
        cases: LegacyMap::<u64, Case>,
        dao_members: LegacyMap::<ContractAddress, Stake>,
        total_stake: u64,
        case_id: u64
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
        CaseResolved: CaseResolved
    }

    #[derive(Drop, Serde, Clone,starknet::Store, starknet::Event)]
    struct LawyerInfo {
        #[key]
        ipfs_hash: ByteArray,
        approved: bool,
        banned: bool,
        votes: u64,
        case_count: u64,
        case_correctly_pred: u64,
        reputation: u64,
        reputation_points_available: u64
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Stake {
        stake_amount: u64,
        at_time: u64,
    }

    #[derive(Drop, Serde, Clone,starknet::Store,starknet::Event)]
    struct Case {
        #[key]
        lawyer_address: ContractAddress,
        case_ipfs_hash: ByteArray,
        case_status: u8,
        created_at: u64,
        case_pred: bool,
        reputation_staked: u64
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
        lawyer_pred: bool
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.owner.write(get_caller_address());
    }

    #[abi(embed_v0)]
    impl xlran of super::Ixlran<ContractState> {
        fn register_dao_amount(ref self: ContractState, stake_amount: u64){
            let caller_adrr = get_caller_address();
            let curr_timestamp = get_block_timestamp();
            assert!(self.dao_members.read(caller_adrr).stake_amount==0,"You have already staked");
            let stake = Stake {
                stake_amount: stake_amount,
                at_time: curr_timestamp
            };
            self.dao_members.write(caller_adrr, stake);
            self.total_stake.write(self.total_stake.read() + stake_amount);
            self.emit(StakeEvent {
                lawyer_address: caller_adrr,
                stake_amount: stake_amount,
                at_time: curr_timestamp
            });
        }

        fn register_lawyer(ref self: ContractState, lawyer_address: ContractAddress, ipfs_hash: ByteArray) {
            let lawyer = LawyerInfo {
                ipfs_hash: ipfs_hash.clone(),
                approved: false,
                banned: false,
                votes: 0,
                case_count: 0,
                case_correctly_pred: 0,
                reputation: 0,
                reputation_points_available: 100
            };
            self.lawyers.write(lawyer_address, lawyer.clone());
            self.emit(lawyer);
        }

        fn register_case(ref self: ContractState, case_ipfs_hash: ByteArray, case_pred: bool, reputation_staked: u64) {
            let lawyer_address = get_caller_address();
            let mut lawyer_info = self.lawyers.read(lawyer_address);

            assert!(lawyer_info.approved, "Lawyer not approved");
            assert!(lawyer_info.reputation_points_available>=reputation_staked, "Not enough reputation stake left");

            lawyer_info.reputation_points_available -= reputation_staked;
            self.lawyers.write(lawyer_address, lawyer_info);

            let case_id = self.case_id.read();
            let case = Case {
                lawyer_address: lawyer_address,
                case_ipfs_hash: case_ipfs_hash,
                case_status: 0,
                created_at: get_block_timestamp(),
                case_pred: case_pred,
                reputation_staked: reputation_staked
            };

            self.cases.write(case_id, case.clone());
            self.case_id.write(case_id + 1);
            self.emit(case);
        }

        fn ban_lawyer(ref self: ContractState, lawyer_address: ContractAddress){
            assert!(get_caller_address()==self.owner.read(),"Only owner can ban lawyer");
            let mut lawyer_info = self.lawyers.read(lawyer_address);
            lawyer_info.banned = true;
            self.lawyers.write(lawyer_address, lawyer_info);
            self.emit(LawyerBanned {
                lawyer_address: lawyer_address
            });
        }

        fn vote_lawyer(ref self: ContractState, lawyer_address: ContractAddress){
            let caller_address = get_caller_address();
            let votes = self.dao_members.read(caller_address).stake_amount;
            let mut lawyer_info = self.lawyers.read(lawyer_address);
            lawyer_info.votes += votes;
            self.lawyers.write(lawyer_address, lawyer_info.clone());
            self.emit(LawyerVoted {
                lawyer_address: lawyer_address,
                votes: lawyer_info.votes
            });
        }

        fn approve_lawyer(ref self: ContractState, lawyer_address: ContractAddress){
            let votes = self.lawyers.read(lawyer_address).votes;
            assert!(votes>=self.total_stake.read()/2,"Lawyer not approved");
            let mut lawyer_info = self.lawyers.read(lawyer_address);
            lawyer_info.approved = true;
            self.lawyers.write(lawyer_address, lawyer_info);
            self.emit(LawyerApproved {
                lawyer_address: lawyer_address
            });
        }

        fn unstake_dao(ref self: ContractState){
            let caller_address = get_caller_address();
            let stake = self.dao_members.read(caller_address);
            self.total_stake.write(self.total_stake.read() - stake.stake_amount);
            self.dao_members.write(caller_address,Stake{stake_amount: 0, at_time: 0});
            self.emit(DaoMemberRemoved {
                dao_member: caller_address
            });
        }

        fn mark_case_resolved(ref self: ContractState, case_id: u64, case_won: bool){
            let lawyer = get_caller_address();
            let mut case = self.cases.read(case_id);

            assert!(case.lawyer_address==lawyer,"You are not the lawyer of this case");
            
            if(case_won){
                case.case_status = 1;
            }else{
                case.case_status = 2;
            };
            self.cases.write(case_id, case.clone());

            let mut lawyer_info = self.lawyers.read(lawyer);
            lawyer_info.case_count += 1;
            lawyer_info.reputation_points_available += case.reputation_staked;
            if(case.case_pred==case_won){
                lawyer_info.case_correctly_pred += 1;
                lawyer_info.reputation += case.reputation_staked;
            }else{
                lawyer_info.reputation -= case.reputation_staked;
            };
            self.lawyers.write(lawyer, lawyer_info);
            self.emit(CaseResolved {
                case_id: case_id,
                lawyer: lawyer,
                case_won: case_won,
                lawyer_pred: case.case_pred
            });
        }

        fn get_lawyer_info(self: @ContractState, lawyer_address: ContractAddress) -> (ByteArray, bool, bool, u64) {
            let lawyer_info = self.lawyers.read(lawyer_address);
            (lawyer_info.ipfs_hash, lawyer_info.approved, lawyer_info.banned, lawyer_info.votes)
        }

        fn read_case(self: @ContractState, case_id: u64) -> (ContractAddress, ByteArray, u8) {
            let case = self.cases.read(case_id);
            (case.lawyer_address, case.case_ipfs_hash, case.case_status)
        }

    }
}