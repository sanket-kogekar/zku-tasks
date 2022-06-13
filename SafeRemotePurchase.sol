// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract Purchase {
    uint public value;
    uint public purchaseTimestamp; 
    address payable public seller;
    address payable public buyer;

    enum State { Created, Locked, Inactive }
    // The state variable has a default value of the first member, `State.created`
    State public state;

    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();
    // Only allowed addresses can access.
    error NotAllowed();

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

    modifier isAllowed() {
        // If msg.sender is not buyer and txn < 5 minutes after the purchaseTimestamp,
        // then we use NotAllowed error
        if (msg.sender != buyer && block.timestamp < purchaseTimestamp + 5 minutes) {
            revert NotAllowed();
        }
        _;
    }

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    event ItemReceived();
    event SellerRefunded();

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        seller = payable(msg.sender);
        value = msg.value / 2;
        if ((2 * value) != msg.value)
            revert ValueNotEven();
    }

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
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
        inState(State.Created)
        condition(msg.value == (2 * value))
        payable
    {
        emit PurchaseConfirmed();
        buyer = payable(msg.sender);
        state = State.Locked;
        purchaseTimestamp = block.timestamp;
    }

    /// This confirms that item was received, and release the funds.
    function completePurchase()
        external
        inState(State.Locked)
        isAllowed
    {
        // we change the state, and then transfer the value
        emit ItemReceived();
        state = State.Inactive; 
        buyer.transfer(value);

        emit SellerRefunded();
        seller.transfer(3 * value);
    }
}

