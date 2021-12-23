// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Compound.sol";

contract LFGlobalEscrow is Ownable {

    // The Compound ICompound contract
    Compound public compound;

    // Mock token address for ETH
    address constant internal ETH_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    enum Sign {
        NULL,
        REVERT,
        RELEASE 
    }
    
    struct Record {
        string referenceId;
        address payable owner;
        address payable sender;
        address payable receiver;
        address payable agent;
        uint256 fund;
        bool disputed;
        bool finalized;
        mapping(address => bool) signer;
        mapping(address => Sign) signed;
        uint256 releaseCount;
        uint256 revertCount;
        uint256 lastTxBlock;
    }

    mapping(string => Record) _escrow;

    constructor( Compound _compound ) {
        compound = _compound;
    }
    
    function owner(string memory _referenceId) public view returns
    (address payable) {
        return _escrow[_referenceId].owner;
    }

    function sender(string memory _referenceId) public view returns
    (address payable) {
        return _escrow[_referenceId].sender;
    }

    function receiver(string memory _referenceId) public view returns
    (address payable) {
        return _escrow[_referenceId].receiver;
    }
    function agent(string memory _referenceId) public view returns
    (address payable) {
        return _escrow[_referenceId].agent;
    }
    function amount(string memory _referenceId) public view returns
    (uint256) {
        return _escrow[_referenceId].fund;
    }

    function isDisputed(string memory _referenceId) public view
    returns (bool) {
        return _escrow[_referenceId].disputed;
    }
    function isFinalized(string memory _referenceId) public view
    returns (bool) {
        return _escrow[_referenceId].finalized;
    }

    function lastBlock(string memory _referenceId) public view
    returns (uint256) {
        return _escrow[_referenceId].lastTxBlock;
    }
    
    function isSigner(string memory _referenceId, address _signer)
    public view returns (bool) {
        return _escrow[_referenceId].signer[_signer];
    }

    function getSignedAction(string memory _referenceId, address _signer) public view returns (Sign) {
        return _escrow[_referenceId].signed[_signer];
    }
    function releaseCount(string memory _referenceId) public view returns (uint256) {
        return _escrow[_referenceId].releaseCount;
    }

    function revertCount(string memory _referenceId) public view returns (uint256) {
        return _escrow[_referenceId].revertCount;
    }
    event Initiated(string referenceId, address payer, uint256 amount, address payee, address trustedParty, uint256 lastBlock);

    //event OwnershipTransferred(string referenceIdHash, address oldOwner, address newOwner, uint256 lastBlock);
    event Signature(string referenceId, address signer, Sign action, uint256 lastBlock);
    event Finalized(string referenceId, address winner, uint256 lastBlock);
    event Disputed(string referenceId, address disputer, uint256 lastBlock);
    event Withdrawn(string referenceId, address payee, uint256 amount, uint256 lastBlock);
    event ETHDeposited(uint256 invested);
    event ETHRemoved(uint256 amount);
    
    modifier multisigcheck(string memory _referenceId) {
        Record storage e = _escrow[_referenceId];
        require(!e.finalized, "LFGlobalEscrow: Escrow should not be finalized");
        require(e.signer[msg.sender], "LFGlobalEscrow: msg sender should be eligible to sign");
        require(e.signed[msg.sender] == Sign.NULL, "LFGlobalEscrow: msg sender should not have signed already"); _;
        if(e.releaseCount == 2) {
            transferOwnership(e);
        }else if(e.revertCount == 2) {
            finalize(e);
        }else if(e.releaseCount == 1 && e.revertCount == 1) {
            dispute(e);

        } 
    }

    function init(string memory _referenceId, address payable _receiver, address payable _agent) public payable {
        require(msg.sender != address(0), "LFGlobalEscrow: Sender should not be null");
        require(_receiver != address(0), "LFGlobalEscrow: Receiver should not be null");
        //require(_trustedParty != address(0), "Trusted Agent should not be null");
        emit Initiated(_referenceId, msg.sender, msg.value, _receiver, _agent, 0);
        Record storage e = _escrow[_referenceId];
        e.referenceId = _referenceId;
        e.owner = payable(msg.sender);
        e.sender = payable(msg.sender);
        e.receiver = _receiver;
        e.agent = _agent;
        e.fund = msg.value;
        e.disputed = false;
        e.finalized = false;
        e.lastTxBlock = block.number;
        e.releaseCount = 0;
        e.revertCount = 0;
        _escrow[_referenceId].signer[msg.sender] = true;
        _escrow[_referenceId].signer[_receiver] = true;
        _escrow[_referenceId].signer[_agent] = true;
    }

    function release(string memory _referenceId) public multisigcheck(_referenceId) {
        Record storage e = _escrow[_referenceId];
        emit Signature(_referenceId, msg.sender, Sign.RELEASE, e.lastTxBlock);
        e.signed[msg.sender] = Sign.RELEASE;
        e.releaseCount++;
    }

    function reverse(string memory _referenceId) public multisigcheck(_referenceId) {
        Record storage e = _escrow[_referenceId];
        emit Signature(_referenceId, msg.sender, Sign.REVERT,
        e.lastTxBlock);
        e.signed[msg.sender] = Sign.REVERT;
        e.revertCount++;
    }

    function dispute(string memory _referenceId) public {
        Record storage e = _escrow[_referenceId];
        require(!e.finalized, "LFGlobalEscrow: Escrow should not be finalized");
        require(msg.sender == e.sender || msg.sender == e.receiver, "LFGlobalEscrow: Only sender or receiver can call dispute");
        dispute(e);
    }

    function transferOwnership(Record storage e) internal {
        e.owner = e.receiver;
        finalize(e);
        e.lastTxBlock = block.number;
    }

    function dispute(Record storage e) internal {
        emit Disputed(e.referenceId, msg.sender, e.lastTxBlock);
        e.disputed = true;
        e.lastTxBlock = block.number;
    }
    
    function finalize(Record storage e) internal {
        require(!e.finalized, "Escrow should not be finalized");
        emit Finalized(e.referenceId, e.owner, e.lastTxBlock);
        e.finalized = true;
    }

    function withdraw(string memory _referenceId, uint256 _amount) public {
        Record storage e = _escrow[_referenceId];
        require(e.finalized, "LFGlobalEscrow: Escrow should be finalized before withdrawal");
        require(msg.sender == e.owner, "LFGlobalEscrow: only owner can withdraw funds");
        require(_amount <= e.fund, "LFGlobalEscrow: cannot withdraw more than the deposit");
        emit Withdrawn(_referenceId, msg.sender, _amount, e.lastTxBlock);
        e.fund = e.fund - _amount;
        e.lastTxBlock = block.number;

        //Withdraw ETH to Compound
        compound.removeInvestment(msg.sender, ETH_TOKEN_ADDRESS, _amount);
        emit ETHRemoved(_amount);
        require((e.owner).send(_amount));
    }

    /**
     * @dev Deposit ETH to Compound
     * @param _amount The amount of ETH to invest
     */
    function deposit(uint256 _amount) external
        returns (uint256 _invested){
        require(_amount <= (msg.sender).balance, "LFGlobalEscrow: LFGlobalEscrow: User should have enough fund");

        //Deposit ETH to Compound
        _invested = compound.addInvestment(msg.sender, ETH_TOKEN_ADDRESS, _amount);
        emit ETHDeposited(_invested);
    }
}