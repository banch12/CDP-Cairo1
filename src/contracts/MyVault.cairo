#[contract]
mod MyVault {

    // USES

    use zeroable::Zeroable;
    use starknet::get_caller_address;
    use starknet::ContractAddressZeroable;
    use starknet::ContractAddressIntoFelt;
    use starknet::FeltTryIntoContractAddress;
    use starknet::contract_address_try_from_felt;
    use traits::Into;
    use traits::TryInto;
    use array::ArrayTrait;
    use option::OptionTrait;

    // Import Base ERC721 contract
    use src::interfaces::IERC721; // Import IERC721 interface
    use src::libraries::ERC721_library::ERC721Library::ERC721Impl;

    use src::interfaces::IOwnable;
    use src::libraries::ownable_library::OwnableLibrary::OwnableImpl;

    use src::interfaces::IERC721MintableBurnable;
    use src::libraries::ERC721MintableBurnableLibrary::ERC721MintableBurnableImpl;

    struct Storage {
    }

    ////////////////////////////////
    // EVENTS
    ////////////////////////////////

    #[event]
    fn Transfer(from: ContractAddress, to: ContractAddress, token_id: u256) {}

    #[event]
    fn Approval(owner: ContractAddress, approved: ContractAddress, token_id: u256) {}

    #[event]
    fn ApprovalForAll(owner: ContractAddress, operator: ContractAddress, approved: bool) {}

    ////////////////////////////////
    // CONSTRUCTOR
    ////////////////////////////////

    #[constructor]
    fn constructor(name_: felt252, symbol_: felt252, owner_: ContractAddress) {
        IERC721::constructor(name_, symbol_);
        IOwnable::initializer(owner_);
    }

    ////////////////////////////////
    // VIEW FUNCTIONS
    ////////////////////////////////

    #[view]
    fn get_name() -> felt {
        IERC721::get_name()
    }

    #[view]
    fn get_symbol() -> felt {
        IERC721::get_symbol()
    }

    #[view]
    fn balance_of(owner: ContractAddress) -> u256 {
        IERC721::balance_of(owner)
    }

    #[view]
    fn owner_of(token_id: u256) -> ContractAddress {
        IERC721::owner_of(token_id)
    }

    #[view]
    fn get_approved(token_id: u256) -> ContractAddress {
        IERC721::get_approved(token_id)
    }

    #[view]
    fn is_approved_for_all(owner: ContractAddress, operator: ContractAddress) -> bool {
        IERC721::is_approved_for_all(owner, operator)
    }

    #[view]
    fn get_token_uri(token_id: u256) -> felt {
        IERC721::get_token_uri(token_id)
    }

    #[view]
    fn owner() -> ContractAddress {
        IOwnable::get_owner()
    }

    ////////////////////////////////
    // EXTERNAL FUNCTIONS
    ////////////////////////////////

    #[external]
    fn transfer_ownership(newOwner: ContractAddress) {
        IOwnable::transfer_ownership()
    }

    #[external]
    fn _transfer_from() {
        assert(1 == 0, "transfer: disabled")
    }

    #[external]
    fn mint(to: ContractAddress, token_id: u256) {
        IOwnable::assert_only_owner();
        IERC721MintableBurnable::_mint(to, token_id);
    }

    #[external]
    fn burn(token_id: u256) {
        IOwnable::assert_only_owner();
        IERC721MintableBurnable::_burn(token_id);
    }
}