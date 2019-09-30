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
    address[] _whitelist_investors;
    uint256[] _whitelist_amounts;
    uint256 _whitelist_length;

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
    
    function whitelist_investors() public view returns (address[] memory) {
        return _whitelist_investors;
    }
    
    function whitelist_amounts() public view returns (uint256[] memory) {
        return _whitelist_amounts;
    }
    
    function add_to_whitelist(address investor, uint256 amount) public onlyPrimary {
        bool already_exists = false;
        for (uint256 i; i < _whitelist_length; i++) {
            if (investor == _whitelist_investors[i]) {
                already_exists = true;
                break;
            }
        }
        require(already_exists == false, "The to-be-added whitelisted investor already exists in the whitelist.");
        _whitelist_investors.push(investor);
        _whitelist_amounts.push(amount);
        _whitelist_length = _whitelist_length.add(1);
    }
    
    function clear_whitelist() public onlyPrimary {
        delete _whitelist_investors;
        delete _whitelist_amounts;
        _whitelist_length = 0;
    }

    function deposit() public payable {
        require(_state == State.Active, "RefundEscrow: can only deposit while active");
        bool found_address = false;
        bool correct_amount = false;
        for (uint256 i; i < _whitelist_length; i++) {
            if (msg.sender == _whitelist_investors[i]) {
                found_address = true;
                if (msg.value == _whitelist_amounts[i]) {
                    correct_amount = true;
                }
                break;
            }
        }
        require(found_address == true, "Only investors in whitelist can invest.");
        require(correct_amount == true, "Investors can only invest in the amount specified in the whitelist.");
        
        address[] memory existing_investors = super.investors();
        uint256 existing_investors_length = existing_investors.length;
        bool already_invested = false;
        for (uint256 i = 0; i < existing_investors_length; i++) {
            if (existing_investors[i] == msg.sender) {
                already_invested = true;
                break;
            }
        }
        require(already_invested == false, "You've already invested before.");
        
        super.deposit();
    }
    
    function refundAll() public payable onlyPrimary {
        require(_state == State.Refunding, "RefundAll: can only refund all while in Refunding state.");
        address[] memory investors = super.investors();
        for (uint256 i = 0; i < investors.length; i++) {
            address payable ap = address(uint160(investors[i]));
            uint256 amount = super.depositsOf(investors[i]);
            ap.transfer(amount);
        }
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

contract BasicToken  {
  using SafeMath for uint256;

  // public variables
  string public name;
  string public symbol;
  uint8 public decimals = 18;

  // internal variables
  uint256 _totalSupply;
  mapping(address => uint256) _balances;
  event Transfer(address indexed from, address indexed to, uint256 value);

  // public functions
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address addr) public view returns (uint256 balance) {
    return _balances[addr];
  }

  function transfer(address to, uint256 value) public returns (bool) {
    require(to != address(0));
    require(value <= _balances[msg.sender]);

    _balances[msg.sender] = _balances[msg.sender].sub(value);
    _balances[to] = _balances[to].add(value);
    emit Transfer(msg.sender, to, value);
    return true;
  }
}

contract StandardToken is BasicToken {
  // internal variables
  mapping (address => mapping (address => uint256)) _allowances;
  event Approval(address indexed owner, address indexed agent, uint256 value);

  // public functions
  function transferFrom(address from, address to, uint256 value) public returns (bool) {
    require(to != address(0));
    require(value <= _balances[from]);
    require(value <= _allowances[from][msg.sender]);

    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    emit Transfer(from, to, value);
    return true;
  }

  function approve(address agent, uint256 value) public returns (bool) {
    _allowances[msg.sender][agent] = value;
    emit Approval(msg.sender, agent, value);
    return true;
  }

  function allowance(address owner, address agent) public view returns (uint256) {
    return _allowances[owner][agent];
  }

  function increaseApproval(address agent, uint value) public returns (bool) {
    _allowances[msg.sender][agent] = _allowances[msg.sender][agent].add(value);
    emit Approval(msg.sender, agent, _allowances[msg.sender][agent]);
    return true;
  }

  function decreaseApproval(address agent, uint value) public returns (bool) {
    uint allowanceValue = _allowances[msg.sender][agent];
    if (value > allowanceValue) {
      _allowances[msg.sender][agent] = 0;
    } else {
      _allowances[msg.sender][agent] = allowanceValue.sub(value);
    }
    emit Approval(msg.sender, agent, _allowances[msg.sender][agent]);
    return true;
  }
}


contract DACCToken is StandardToken {
  // public variables
  string public name = "Decentralized Accessible Content Chain";
  string public symbol = "DACC";
  uint8 public decimals = 6;

  // public functions
  constructor() public {
    //init _totalSupply
    _totalSupply = 30 * (10 ** 9) * (10 ** uint256(decimals));

    _balances[msg.sender] = _totalSupply;
  }
}
