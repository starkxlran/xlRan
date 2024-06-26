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

#[test]
fn test_no_double_voting() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(2);  // Register 2 DAO token votes

    let lawyer = dispatcher.register_lawyer("lawyer");

    dispatcher.vote_lawyer(lawyer);
    
    assert!(dispatcher.unstake_dao().is_err(),"Unstaking should not be possible when lawyer is not approved!");
}

#[test]
fn test_dao_vote_on_settlement_oracle() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer1");
    dispatcher.approve_lawyer(lawyer);

    let case_id = dispatcher.register_case("case1", true, 1000);

    let oracle: ContractAddress = contract_address_const::<1>();

    dispatcher.vote_case_oracle(case_id, oracle);
    dispatcher.declare_oracle(case_id, oracle);

    let test_oracle = dispatcher.get_case_oracle(case_id);
    assert_eq!(test_oracle, oracle);
}

#[test]
fn test_case_settlement() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer");
    dispatcher.approve_lawyer(lawyer);

    let case_id = dispatcher.register_case("case1", true, 1000,1000000000,1000);

    dispatcher.vote_case_oracle(case_id, oracle);
    dispatcher.declare_oracle(case_id, oracle);

    assert_eq(dispatcher.mark_case_resolved(case_id, true, 1000),dispatcher.get_oracle_result(case_id));
}

#[test]
fn test_case_settlement_post_deadline() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer");
    dispatcher.approve_lawyer(lawyer);

    let case_id = dispatcher.register_case("case1", true, 1000, 1,1000);

    dispatcher.vote_case_oracle(case_id, oracle);
    dispatcher.declare_oracle(case_id, oracle);
    sleep(1);
    assert_eq(dispatcher.mark_case_resolved(case_id, true, 1000),dispatcher.get_oracle_result(case_id));
}

#[test]
fn test_post_case_money_distribution() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer");
    dispatcher.approve_lawyer(lawyer);
    let case_id = dispatcher.register_case("case1", true, 1000, 1000000000,1000);
    dispatcher.vote_case_oracle(case_id, oracle);
    dispatcher.declare_oracle(case_id, oracle);
    dispatcher.invest_money(case_id,300);
    assert_eq(dispatcher.mark_case_resolved(case_id, true, 1000),dispatcher.get_oracle_result(case_id));

    let investor_money = dispatcher.get_investor_pending_money(case_id);
    assert_eq!(investor_money, 300);
    let investor_claimed_money = dispatcher.claim_investor_money(case_id);
    assert_eq!(investor_claimed_money, 300);
}

#[test]
fn test_cant_over_invest() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer");
    dispatcher.approve_lawyer(lawyer);
    let case_id = dispatcher.register_case("case1", true, 1000, 1000000000,1000);
    dispatcher.vote_case_oracle(case_id, oracle);
    dispatcher.declare_oracle(case_id, oracle);
    assert!(dispatcher.invest_money(case_id,1000).is_err(),"Investment above 30% of case value are not allowed!");
}

#[test]
fn test_cant_invest_after_deadline() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer");
    dispatcher.approve_lawyer(lawyer);
    let case_id = dispatcher.register_case("case1", true, 1000, 1,1000);
    dispatcher.vote_case_oracle(case_id, oracle);
    dispatcher.declare_oracle(case_id, oracle);
    sleep(1);
    assert!(dispatcher.invest_money(case_id,1000).is_err(),"Investment should not be possible after deadline!");
}

#[test]
fn test_voting_on_dao_fees() {
    let dispatcher = setup_contract();
    dispatcher.register_dao_amount(3);

    let lawyer = dispatcher.register_lawyer("lawyer");
    dispatcher.approve_lawyer(lawyer);
    let case_id = dispatcher.register_case("case1", true, 1000, 1,1000);
    dispatcher.vote_dao_fees(5);
    dispatcher.declare_dao_fees();
    assert_eq!(dispatcher.get_dao_fees(),5);
}

#[test]
fn test_multiple_lawyer_nultiple_voter_scenario() {
    let contract_address = deploy_contract("xlran");
    let dispatcher_1 = IxlranDispatcher { contract_address}
    let dispatcher_2 = IxlranDispatcher { contract_address}
    dispatcher_1.register_dao_amount(3);    
    dispatcher_2.register_dao_amount(1);

    let lawyer_1 = dispatcher_1.register_lawyer("lawyer");
    let lawyer_2 = dispatcher_2.register_lawyer("lawyer");

    dispatcher_1.vote_lawyer(lawyer_1);
    dispatcher_2.vote_lawyer(lawyer_2);

    dispatcher_1.approve_lawyer(lawyer_1);
    require!(dispatcher_2.approve_lawyer(lawyer_2).is_err(),"Lawyer 2 should not be able to approve at below 50% voting threshhold!");
    dispatcher_1.approve_lawyer(lawyer_2);
    
    dispatcher_2.approve_lawyer(lawyer_2);
}
