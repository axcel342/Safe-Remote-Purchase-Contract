// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
import "hardhat/console.sol";



contract Purchase {
    uint public value;     
    uint public _Blockstamp;
    address payable public seller;      //address used to send seller ether
    address payable public buyer;       //address used to send buyer ether
    uint constant Min_delay = 300; 
    enum State { Created, Locked, Release, Inactive }   //State is initialized by Created and can be changed to All three
                                                        //if buyer makes purchase we set State to Locked, if he confirms purchase we set it to Release                 

    // The state variable has a default value of the first member, `State.created`
    State public state;

    


    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    /// Only the buyer can call this function.
    error OnlyBuyer();
    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();
    error TimestampNotInRangeError(uint blocktimestamp,uint _timestamp);

    //modifier lets us reuse code, any function with name of modifier results in modifier being called first

    modifier onlyBuyer() {
        if (msg.sender != buyer)
            revert OnlyBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller)
            revert OnlySeller();
        _;
    }

    modifier inState(State state_) {
        if (state != state_)
            revert InvalidState();
        _;
    }

    modifier BuyerorTimeElapsed(uint _timestamp){                   //parameter is current timestamp
        if (msg.sender != buyer )                //checks if user is not buyer 
        {
            if(_timestamp < _Blockstamp + Min_delay)    //checks if timestamp < 5mins
            {
            console.log(block.timestamp);                                               //logs current time stamp on terminal            
            revert TimestampNotInRangeError(_Blockstamp, _timestamp);                   //reverts changes and throws error
            }
        }    
        _;
    }

    //events help store data on the blockchain, not sure how their initialised yet but event Log(string x) saves x to blockchain 
    //emit used to call these events
    event Aborted();
    event PurchaseConfirmed();
    event ItemReceived();
    event SellerRefunded();
    event itworks();

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        seller = payable(msg.sender);       //initialse seller address to contract caller when contract deployed
        value = msg.value / 2;
        if ((2 * value) != msg.value)
            revert ValueNotEven();
    }

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.

    function getTimestamp()
        external
        view
        returns (uint)
    {
        return  block.timestamp;
    }

    function abort()
        external
        onlySeller
        inState(State.Created)
    {
        emit Aborted();
        state = State.Inactive;
        // We use transfer here directly. It is
        // reentrancy-safe, because it is the
        // last call in this function and we
        // already changed the state.
        seller.transfer(address(this).balance);
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase()
        external
        inState(State.Created)                  //check if state is created  
        condition(msg.value == (2 * value))     //check if value is half of original value
        payable                                 //needed to be included for transaction functions                
    {
        emit PurchaseConfirmed();               
        buyer = payable(msg.sender);            //
        state = State.Locked;
        _Blockstamp = block.timestamp;
    }

    function getbalance() external view returns (uint){
        return address(this).balance;
    }

    /// Confirm that you (the buyer) received the item.
    /// This will release the locked ether.
    function confirmReceived()
        external
        onlyBuyer
        inState(State.Locked)
    {
        emit ItemReceived();
        // It is important to change the state first because
        // otherwise, the contracts called using `send` below
        // can call in again here.
        state = State.Release;

        buyer.transfer(value);                  //transfer buyer his half his money back
    }

    /// This function refunds the seller, i.e.
    /// pays back the locked funds of the seller.
    function refundSeller()
        external
        onlySeller
        inState(State.Release)
    {
        emit SellerRefunded();
        // It is important to change the state first because
        // otherwise, the contracts called using `send` below
        // can call in again here.
        state = State.Inactive;                 //inorder to prevent multiple contract calls

        seller.transfer(3 * value);             //transfer the seller 3 times money back 2 times his 1 times of sold item           
    }

    function completePurchase()
        external
        inState(State.Locked)                           
        BuyerorTimeElapsed(block.timestamp)             //calls buyerortimeelapsed modifier
    {
        emit itworks();
        state = State.Release;                          //state set to release
        state = State.Inactive;                         //state set to inactive    
        seller.transfer(3 * value);                     //Seller returned his deposit plus price on item sold    
        buyer.transfer(value);                          //buyer returned half deposit    
        console.log(block.timestamp);                   //console log to check current timestamp
    }
}