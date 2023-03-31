#[contract]
mod ReentrancyGuardLibrary {
    use zeroable::Zeroable;
    use starknet::get_caller_address;
    use starknet::ContractAddressZeroable;
    use starknet::ContractAddressIntoFelt;
    use src::corelib_extension::ContractAddressPartialEq;
    use starknet::FeltTryIntoContractAddress;
    use starknet::contract_address_try_from_felt;
    use traits::Into;
    use traits::TryInto;
    use array::ArrayTrait;
    use option::OptionTrait;

    use src::interfaces::IReentrancyGuard;
    use src::corelib_extension::StorageAccessContractAddress;


    ////////////////////////////////
    // STORAGE
    ////////////////////////////////

    struct Storage {
        status: felt252, 
    }

    const _NOT_ENTERED: felt252 = 1;
    const _ENTERED: felt252 = 2;

    impl ReentrancyGuardImpl of IReentrancyGuard {
        ////////////////////////////////
        // CONSTRUCTOR
        ////////////////////////////////

        fn constructor() {
            status::write(_NOT_ENTERED)
        }

        ////////////////////////////////
        // GUARDS
        ////////////////////////////////

        fn nonReentrant() {
            _nonReentrantBefore();
            _nonReentrantAfter();
        }

        ////////////////////////////////
        // VIEW FUNCTIONS
        ////////////////////////////////

	#[view]
        fn _reentrancyGuardEntered()() -> felt252 {
            let _status = status::read();
	    if (_status == _ENTERED) {
	        return 1;
	    }
	    0 // return 0
        }

        ////////////////////////////////
        // INTERNAL FUNCTIONS
        ////////////////////////////////

        fn _nonReentrantBefore() {
	    let _status = status::read();

	    // On the first call to nonReentrant, _status will be _NOT_ENTERED
	    assert(_status != _ENTERED, 'ReentrancyGuard: reentrant call');

	    // Any calls to nonReentrant after this point will fail
	    status::write(_ENTERED);
	    return();
        }

        fn _nonReentrantAfter() {
	    // By storing the original value once again, a refund is triggered (see
    	    // https://eips.ethereum.org/EIPS/eip-2200)
	    status::write(_NOT_ENTERED);
	    return();
	}
    }
}
