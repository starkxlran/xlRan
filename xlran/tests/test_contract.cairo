use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait};
use xlran::{IxlranSafeDispatcher, IxlranSafeDispatcherTrait, IxlranDispatcher, IxlranDispatcherTrait};

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

fn setup_contract() -> IxlranDispatcher {
    let contract_address = deploy_contract("xlran");
    IxlranDispatcher { contract_address }
}

#[test]
fn test_register_lawyer() {
    let dispatcher = setup_contract();
    let lawyer_address = dispatcher.register_lawyer("aa");

    let (hash, approved, banned, votes) = dispatcher.get_lawyer_info(lawyer_address);
    assert_eq!(hash, "aa");
    assert_eq!(approved, false);
    assert_eq!(banned, false);
    assert_eq!(votes, 0);
}

#[test]
fn test_dao_member_voting() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(1);

    let lawyer_address = dispatcher.register_lawyer("aa");
    dispatcher.vote_lawyer(lawyer_address);

    let (_, _, _, votes) = dispatcher.get_lawyer_info(lawyer_address);
    assert_eq!(votes, 1);
}

#[test]
fn test_lawyer_approval() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(1);

    let lawyer_address = dispatcher.register_lawyer("aa");
    dispatcher.vote_lawyer(lawyer_address);
    dispatcher.approve_lawyer(lawyer_address);

    let (_, approved, _, _) = dispatcher.get_lawyer_info(lawyer_address);
    assert_eq!(approved, true);
}

#[test]
fn test_register_case() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(1);

    let lawyer_address = dispatcher.register_lawyer("aa");
    dispatcher.vote_lawyer(lawyer_address);
    dispatcher.approve_lawyer(lawyer_address);

    let case_id = dispatcher.register_case("a", true, 1, 1, 1);
    let (case_lawyer_addr, ipsf_hash, status) = dispatcher.read_case(case_id);
    assert_eq!(case_lawyer_addr, lawyer_address);
    assert_eq!(ipsf_hash, "a");
    assert_eq!(status, 0);
}

#[test]
fn test_ban_lawyer() {
    let dispatcher = setup_contract();
    let lawyer_address = dispatcher.register_lawyer("aa");

    dispatcher.ban_lawyer(lawyer_address);
    let (_, _, banned, _) = dispatcher.get_lawyer_info(lawyer_address);
    assert_eq!(banned, true);
}

#[test]
fn test_unstaking() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(2);  // Register 2 DAO token votes

    let lawyer = dispatcher.register_lawyer("lawyer");

    dispatcher.vote_lawyer(lawyer);
    dispatcher.approve_lawyer(lawyer);

    let stake_amount = dispatcher.unstake_dao();
    assert_eq!(stake_amount, 2);
}

// #[test]
// fn test_no_double_voting() {
//     let dispatcher = setup_contract();
//     dispatcher.register_dao_amount(2);  // Register 2 DAO token votes

//     let lawyer = dispatcher.register_lawyer("lawyer");

//     dispatcher.vote_lawyer(lawyer);
    
//     // assert!(dispatcher.unstake_dao().is_err(),"Unstaking should not be possible when lawyer is not approved!");
// }

#[test]
fn test_dao_vote_on_settlement_oracle() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer1");
    dispatcher.vote_lawyer(lawyer);
    dispatcher.approve_lawyer(lawyer);

    let case_id = dispatcher.register_case("case1", true, 1,1000000000,1000);
    let addr: felt252 = 0x041a78e741e5af2fec34b695679bc6891742439f7afb8484ecd7766661ad02bf; 
    let oracle: ContractAddress = addr.try_into().unwrap();

    dispatcher.vote_oracle(case_id, oracle);

    let test_oracle = dispatcher.get_case_oracle(case_id);
    assert_eq!(test_oracle, oracle);
}

// #[test]
// fn test_case_settlement() {
//     let dispatcher = setup_contract();
//     dispatcher.register_dao_amount(3);

//     let lawyer = dispatcher.register_lawyer("lawyer");
//     dispatcher.vote_lawyer(lawyer);
//     dispatcher.approve_lawyer(lawyer);

//     let case_id = dispatcher.register_case("case1", true, 1,1,1000);
//     assert_eq!(dispatcher.mark_case_resolved(case_id, true, 1000),true);
// }

#[test]
fn test_case_settlement_without_pred() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer");
    dispatcher.vote_lawyer(lawyer);
    dispatcher.approve_lawyer(lawyer);

    let case_id = dispatcher.register_case("case1", true, 1,100000000000,1000);
    let addr: felt252 = 0x041a78e741e5af2fec34b695679bc6891742439f7afb8484ecd7766661ad02bf; 
    let oracle: ContractAddress = addr.try_into().unwrap();

    dispatcher.vote_oracle(case_id, oracle);
    assert_eq!(dispatcher.mark_case_resolved(case_id, true, 10),false);
}

// #[test]
// fn test_post_case_money_distribution() {
//     let dispatcher = setup_contract();
//     dispatcher.register_dao_amount(3);

//     let lawyer = dispatcher.register_lawyer("lawyer");
//     dispatcher.approve_lawyer(lawyer);
//     let case_id = dispatcher.register_case("case1", true, 1000, 1000000000,1000);
//     dispatcher.vote_case_oracle(case_id, oracle);
//     dispatcher.invest_money(case_id,300);
//     assert_eq(dispatcher.mark_case_resolved(case_id, true, 1000),dispatcher.get_oracle_result(case_id));

//     let investor_money = dispatcher.get_investor_pending_money(case_id);
//     assert_eq!(investor_money, 300);
//     let investor_claimed_money = dispatcher.claim_investor_money(case_id);
//     assert_eq!(investor_claimed_money, 300);
// }

#[test]
#[should_panic(expected: ("Can not invest over maximum comission",))]
fn test_cant_over_invest() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer");
    dispatcher.vote_lawyer(lawyer);
    dispatcher.approve_lawyer(lawyer);
    let case_id = dispatcher.register_case("case1", true, 1, 1000000000,1000);
    dispatcher.invest_in_case(case_id,1000);
}

#[test]
fn test_voting_on_dao_fees() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    // dispatcher.vote_dao_fees(5);
    // dispatcher.declare_new_dao_fee(5);
    // assert_eq!(dispatcher.get_dao_fees(),5);
}

// #[test]
// fn test_multiple_lawyer_nultiple_voter_scenario() {
//     let contract_address = deploy_contract("xlran");
//     let dispatcher_1 = IxlranDispatcher { contract_address};
//     let dispatcher_2 = IxlranDispatcher { contract_address};
//     dispatcher_1.register_dao_amount(3);    
//     dispatcher_2.register_dao_amount(1);

//     let lawyer_1 = dispatcher_1.register_lawyer("lawyer");
//     let lawyer_2 = dispatcher_2.register_lawyer("lawyer");

//     dispatcher_1.vote_lawyer(lawyer_1);
//     dispatcher_2.vote_lawyer(lawyer_2);

//     dispatcher_1.approve_lawyer(lawyer_1);
// }

#[test]
#[should_panic(expected: ("Lawyer already exists!",))]
fn test_prevent_duplicate_lawyer_registration() {
    let dispatcher = setup_contract();
    let _ = dispatcher.register_lawyer("aa");

    // Attempt to register the same lawyer again
    let _ = dispatcher.register_lawyer("aa");
}

#[test]
#[should_panic(expected: ("Case deadline has passed",))]
fn test_case_registration_with_invalid_parameters() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(1);

    let lawyer_address = dispatcher.register_lawyer("aa");
    dispatcher.vote_lawyer(lawyer_address);
    dispatcher.approve_lawyer(lawyer_address);

    // Attempt to register case with unrealistic deadline (e.g., past deadline)
    let _ = dispatcher.register_case("a", true, 1, 0, 1);
}

#[test]
fn test_oracle_voting_after_case_resolution() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer");
    dispatcher.vote_lawyer(lawyer);
    dispatcher.approve_lawyer(lawyer);

    let case_id = dispatcher.register_case("case1", true, 1, 1000000000, 1000);
    let addr: felt252 = 0x041a78e741e5af2fec34b695679bc6891742439f7afb8484ecd7766661ad02bf; 
    let oracle: ContractAddress = addr.try_into().unwrap();

    dispatcher.vote_oracle(case_id, oracle);

    dispatcher.mark_case_resolved(case_id, true, 1000);

    // Attempt to vote for oracle after case is resolved
    let _ = dispatcher.vote_oracle(case_id, oracle);
}

// #[test]
// fn test_multiple_investors_distribution() {
//     let dispatcher = setup_contract();
//     dispatcher.register_dao_amount(3);

//     let lawyer = dispatcher.register_lawyer("lawyer");
//     dispatcher.approve_lawyer(lawyer);

//     let case_id = dispatcher.register_case("case1", true, 1000, 1000000000, 1000);
//     let oracle: ContractAddress = contract_address_const::<1>();

//     dispatcher.vote_case_oracle(case_id, oracle);

//     // Multiple investors
//     dispatcher.invest_money(case_id, 100);  // Investor 1
//     let dispatcher2 = IxlranDispatcher { contract_address: dispatcher.contract_address };
//     dispatcher2.invest_money(case_id, 200);  // Investor 2

//     dispatcher.mark_case_resolved(case_id, true, 1000);

//     // Check distribution
//     let investor1_money = dispatcher.get_investor_pending_money(case_id);
//     let investor2_money = dispatcher2.get_investor_pending_money(case_id);

//     assert_eq!(investor1_money, 100);
//     assert_eq!(investor2_money, 200);

//     let claimed1 = dispatcher.claim_investor_money(case_id);
//     let claimed2 = dispatcher2.claim_investor_money(case_id);

//     assert_eq!(claimed1, 100);
//     assert_eq!(claimed2, 200);
// }

#[test]
#[should_panic(expected: ("Lawyer is banned from joining or performing any contract actions!",))]
fn test_banned_lawyer_restrictions() {
    let dispatcher = setup_contract();
    let lawyer_address = dispatcher.register_lawyer("aa");
    dispatcher.vote_lawyer(lawyer_address);
    dispatcher.approve_lawyer(lawyer_address);

    dispatcher.ban_lawyer(lawyer_address);

    // Attempt to register a new case with banned lawyer
    let _ = dispatcher.register_case("a", true, 1, 1000000000, 1000);
}

#[test]
#[should_panic(expected: ("You have an active vote on dao fees, please unstake it to exit from the dao!",))]
fn test_unstaking_with_pending_votes() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(2);
    // attempt to unstake with pending dao fee votes
    dispatcher.vote_dao_fees(3);
    // Attempt to unstake with pending case oracle vote
    let _ = dispatcher.unstake_dao();
}