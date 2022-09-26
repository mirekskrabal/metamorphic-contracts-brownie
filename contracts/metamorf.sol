//SPDX-License-Identifier: MIT
//code is from: https://ethereum-blockchain-developer.com/110-upgrade-smart-contracts/12-metamorphosis-create2/
//^ is in turn based on: https://github.com/0age/metamorphic

pragma solidity 0.8.1;

contract Factory {
    mapping (address => address) _implementations;
    
    event Deployed(address _addr);

    function deploy(uint salt, bytes calldata bytecode) public {

        bytes memory implInitCode = bytecode;

   
        // metamorphic contract initialization code
         bytes memory metamorphicCode  = (
           hex"5860208158601c335a63aaf10f428752fa158151803b80938091923cf3"
         );

          // determine the address of the metamorphic contract.
        address metamorphicContractAddress = getMetamorphicContractAddress(salt, metamorphicCode);

        // declare a variable for the address of the implementation contract.
        address implementationContract;

        // load implementation init code and length, then deploy via CREATE.
        /* solhint-disable no-inline-assembly */
        assembly {
          let encoded_data := add(0x20, implInitCode) // load initialization code.
          let encoded_size := mload(implInitCode)     // load init code's length.
          implementationContract := create(       // call CREATE with 3 arguments.
            0,                                    // do not forward any endowment.
            encoded_data,                         // pass in initialization code.
            encoded_size                          // pass in init code's length.
          )
        } /* solhint-enable no-inline-assembly */

        //first we deploy the code we want to deploy on a separate address
        // store the implementation to be retrieved by the metamorphic contract.
        _implementations[metamorphicContractAddress] = implementationContract;



        address addr;
        assembly {
            let encoded_data := add(0x20, metamorphicCode) // load initialization code.
            let encoded_size := mload(metamorphicCode)     // load init code's length.
            addr := create2(0, encoded_data, encoded_size, salt)
        }

         require(
          addr == metamorphicContractAddress,
          "Failed to deploy the new metamorphic contract."
        );
        emit Deployed(addr);
    }

    /**
    * @dev Internal view function for calculating a metamorphic contract address
    * given a particular salt.
    */
    function getMetamorphicContractAddress(
        uint256 salt,
        bytes memory metamorphicCode
        ) public view returns (address) {

        // determine the address of the metamorphic contract.
        return address(
          uint160(                      // downcast to match the address type.
            uint256(                    // convert to uint to truncate upper digits.
              keccak256(                // compute the CREATE2 hash using 4 inputs.
                abi.encodePacked(       // pack all inputs to the hash together.
                  hex"ff",              // start with 0xff to distinguish from RLP.
                  address(this),        // this contract will be the caller.
                  salt,                 // pass in the supplied salt value.
                  keccak256(
                      abi.encodePacked(
                        metamorphicCode
                      )
                    )     // the init code hash.
                )
              )
            )
          )
        );
    }

    //those two functions are getting called by the metamorphic Contract
    function getImplementation() external view returns (address implementation) {
        return _implementations[msg.sender];
    }

}

contract Test1 {
    uint public myUint;

    function setUint(uint _myUint) public {
        myUint = _myUint;
    }

    function killme() public {
        selfdestruct(payable(msg.sender));
    }
}

contract Test2 {
    uint public myUint;

    function setUint(uint _myUint) public {
        myUint = 2*_myUint;
    }

    function killme() public {
        selfdestruct(payable(msg.sender));
    }

}

/**
    * Metamorphic contract initialization code (29 bytes): 
    * 
    * 0x5860208158601c335a63aaf10f428752fa158151803b80938091923cf3
    * 
    * Description:
    * 
    * pc|op|name         | [stack]                                | <memory>
    * 
    * ** set the first stack item to zero - used later **
    * 00 58 getpc          [0]                                       <>
    * 
    * ** set second stack item to 32, length of word returned from staticcall **
    * 01 60 push1
    * 02 20 outsize        [0, 32]                                   <>
    * 
    * ** set third stack item to 0, position of word returned from staticcall **
    * 03 81 dup2           [0, 32, 0]                                <>
    * 
    * ** set fourth stack item to 4, length of selector given to staticcall **
    * 04 58 getpc          [0, 32, 0, 4]                             <>
    * 
    * ** set fifth stack item to 28, position of selector given to staticcall **
    * 05 60 push1
    * 06 1c inpos          [0, 32, 0, 4, 28]                         <>
    * 
    * ** set the sixth stack item to msg.sender, target address for staticcall **
    * 07 33 caller         [0, 32, 0, 4, 28, caller]                 <>
    * 
    * ** set the seventh stack item to msg.gas, gas to forward for staticcall **
    * 08 5a gas            [0, 32, 0, 4, 28, caller, gas]            <>
    * 
    * ** set the eighth stack item to selector, "what" to store via mstore **
    * 09 63 push4
    * 10 aaf10f42 selector [0, 32, 0, 4, 28, caller, gas, 0xaaf10f42]    <>
    * aaf10f42 is selctor of: function getImplementation() external view returns (address implementation); 
    * ** set the ninth stack item to 0, "where" to store via mstore ***
    * 11 87 dup8           [0, 32, 0, 4, 28, caller, gas, 0xaaf10f42, 0] <>
    * 
    * ** call mstore, consume 8 and 9 from the stack, place selector in memory **
    * 12 52 mstore         [0, 32, 0, 4, 0, caller, gas]             <0xaaf10f42>
    * 
    * ** call staticcall, consume items 2 through 7, place address in memory **
    * 13 fa staticcall     [0, 1 (if successful)]                    <address>
    * 
    * ** flip success bit in second stack item to set to 0 **
    * 14 15 iszero         [0, 0]                                    <address>
    * 
    * ** push a third 0 to the stack, position of address in memory **
    * 15 81 dup2           [0, 0, 0]                                 <address>
    * 
    * ** place address from position in memory onto third stack item **
    * 16 51 mload          [0, 0, address]                           <>
    * 
    * ** place address to fourth stack item for extcodesize to consume **
    * 17 80 dup1           [0, 0, address, address]                  <>
    * 
    * ** get extcodesize on fourth stack item for extcodecopy **
    * 18 3b extcodesize    [0, 0, address, size]                     <>
    * 
    * ** dup and swap size for use by return at end of init code **
    * 19 80 dup1           [0, 0, address, size, size]               <> 
    * 20 93 swap4          [size, 0, address, size, 0]               <>
    * 
    * ** push code position 0 to stack and reorder stack items for extcodecopy **
    * 21 80 dup1           [size, 0, address, size, 0, 0]            <>
    * 22 91 swap2          [size, 0, address, 0, 0, size]            <>
    * 23 92 swap3          [size, 0, size, 0, 0, address]            <>
    * 
    * ** call extcodecopy, consume four items, clone runtime code to memory **
    * 24 3c extcodecopy    [size, 0]                                 <code>
    * 
    * ** return to deploy final code in memory **
    * 25 f3 return         []                                        *deployed!*
    * 
    * TLDR:
    * retrieve a contract address from the caller using a static call
    * copy the code from the retrieved address to memory and return
    */

