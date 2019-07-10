pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

/**
 * @dev A Secondary contract can only be used by its primary account (the one that created it).
 */
contract Secondary {
    address private _primary;

    /**
     * @dev Emitted when the primary contract changes.
     */
    event PrimaryTransferred(
        address recipient
    );

    /**
     * @dev Sets the primary account to the one that is creating the Secondary contract.
     */
    constructor () internal {
        _primary = msg.sender;
        emit PrimaryTransferred(_primary);
    }

    /**
     * @dev Reverts if called from any account other than the primary.
     */
    modifier onlyPrimary() {
        require(msg.sender == _primary, "Secondary: caller is not the primary account");
        _;
    }

    /**
     * @return the address of the primary.
     */
    function primary() public view returns (address) {
        return _primary;
    }

    /**
     * @dev Transfers contract to a new primary.
     * @param recipient The address of new primary.
     */
    function transferPrimary(address recipient) public onlyPrimary {
        require(recipient != address(0), "Secondary: new primary is the zero address");
        _primary = recipient;
        emit PrimaryTransferred(_primary);
    }
}

contract Escrow is Secondary {
    using SafeMath for uint256;

    address[] _investors;
    uint256 _investorCount = 0;
    mapping(address => uint256) private _deposits;

    function depositsOf(address payee) public view returns (uint256) {
        return _deposits[payee];
    }
    
    function investors() public view returns (address[] memory) {
        return _investors;
    }

    function deposit() public payable {
        _investors.push(msg.sender);
        _investorCount = _investorCount.add(1);
        
        uint256 amount = msg.value;
        _deposits[msg.sender] = _deposits[msg.sender].add(amount);
    }


    function withdraw() public {
        uint256 payment = _deposits[msg.sender];
        _deposits[msg.sender] = 0;
        msg.sender.transfer(payment);
    }
}

contract ConditionalEscrow is Escrow {
    function withdrawalAllowed() public view returns (bool);

    function withdraw() public {
        require(withdrawalAllowed(), "ConditionalEscrow: payee is not allowed to withdraw");
        super.withdraw();
    }
}

contract RefundEscrow is ConditionalEscrow {
    enum State { Active, Closed, Refunding, Released }

    State private _state;
    address payable private _beneficiary;

    constructor (address payable beneficiary) public {
        require(beneficiary != address(0), "RefundEscrow: beneficiary is the zero address");
        _beneficiary = beneficiary;
        _state = State.Active;
    }

    function state() public view returns (State) {
        return _state;
    }

    function beneficiary() public view returns (address) {
        return _beneficiary;
    }
    
    function totalBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function deposit() public payable {
        require(_state == State.Active, "RefundEscrow: can only deposit while active");
        super.deposit();
    }
    
    function activate() public onlyPrimary {
        require(_state == State.Closed, "RefundEscrow: can only activate while closed");
        _state = State.Active;
    }

    function close() public onlyPrimary {
        require(_state == State.Active, "RefundEscrow: can only close while active");
        _state = State.Closed;
    }
    
    function enableReleased() public onlyPrimary {
        require(_state == State.Closed, "RefundEscrow: can only release while closed");
        _state = State.Released;
    }

    function enableRefunds() public onlyPrimary {
        require(_state == State.Closed, "RefundEscrow: can only enable refunds while closed");
        _state = State.Refunding;
    }

    function beneficiaryWithdraw() public {
        require(_state == State.Released, "RefundEscrow: beneficiary can only withdraw while released");
        _beneficiary.transfer(address(this).balance);
    }

    function withdrawalAllowed() public view returns (bool) {
        return _state == State.Refunding;
    }
}
