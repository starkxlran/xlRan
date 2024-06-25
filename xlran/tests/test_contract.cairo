use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait};

use xlran::IxlranSafeDispatcher;
use xlran::IxlranSafeDispatcherTrait;
use xlran::IxlranDispatcher;
use xlran::IxlranDispatcherTrait;


fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_register_lawyer() {
    let contract_address = deploy_contract("xlran");
    let dispatcher = IxlranDispatcher { contract_address };
    let lawyer_address = dispatcher.register_lawyer("aa");

    let (hash,approved,banned,votes) = dispatcher.get_lawyer_info(lawyer_address);
    assert_eq!(hash, "aa");
    assert_eq!(approved, false);
    assert_eq!(banned, false);
    assert_eq!(votes, 0);
}

#[test]
fn test_dao_member_voting_and_lawyer_approve(){
    let contract_address = deploy_contract("xlran");
    let dispatcher = IxlranDispatcher { contract_address };
    dispatcher.register_dao_amount(1);

    let lawyer_address = dispatcher.register_lawyer("aa");
    dispatcher.vote_lawyer(lawyer_address);
    dispatcher.approve_lawyer(lawyer_address);

    let (_,approved,_,votes) = dispatcher.get_lawyer_info(lawyer_address);
    assert_eq!(approved,true);
    assert_eq!(votes,1);

    let case_id = dispatcher.register_case("a",true,1);
    let (case_lawyer_addr,ipsf_hash,status) = dispatcher.read_case(case_id);
    assert_eq!(case_lawyer_addr, lawyer_address);
    assert_eq!(ipsf_hash, "a");
    assert_eq!(status, 0);
}

#[test]
fn test_ban_lawyer(){
    let contract_address = deploy_contract("xlran");
    let dispatcher = IxlranDispatcher { contract_address };
    let lawyer_address = dispatcher.register_lawyer("aa");

    dispatcher.ban_lawyer(lawyer_address);
    let (_,_,banned,_) = dispatcher.get_lawyer_info(lawyer_address);
    assert_eq!(banned,true);
}