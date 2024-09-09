// SPDX-License-Identifier: GTC-Protocol-1.0
pragma solidity 0.8.27;

import "../interfaces/IERC20.sol";
import "../interfaces/IChainBridge.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ERC20ChainBridge is IChainBridge, ReentrancyGuard {

    struct Origin {
        address originalContractAddress;
    }

    struct Foreign {
        address originalContractAddress;
        address wrappedContractAddress;
        uint64 chainId;
    }

    struct Chain {
        uint64 chainId;
        string chainName;
    }

    struct Logs {
        address receiver;
        address originalContractAddress;
        bytes32 transactionHash;
        uint256 numTokens;
        string message;
        uint64 chainId;
        bool verify;
    }

    mapping (address => Origin) public ERC20Origin;
    mapping (address => mapping (uint64 => Foreign)) public ERC20Foreign;
    mapping (address => Foreign[]) public ERC20TokenListForeign;
    mapping (address => bool vested) public isVested;
    mapping (address => mapping (address => bool vested)) public userERC20VestedPermit;
    mapping (address => uint256) public ERC20VestedBalance;
    Origin[] public ERC20TokenListOrigin;
    Chain[] public chainList;

    mapping (address => Logs) public transactionLogs;
    uint256 public collectedFees;

    // Owner and developer-related addresses
    address public owner;
    address public backupAddress;
    address public devOps;
    address public extension;
    address public developerWallet;

    address public nodeOperator1;
    address public nodeOperator2;
    address public nodeOperator3;

    address public protocol;
    address public backupProtocol;
    
    uint256 public transactionFee;  // Fee in base token for each transaction

    event SendBridge(address indexed sender, address indexed receiver, address indexed originalContractAddress, uint256 numTokens, string message, uint64 chainDestination);
    event AcceptBridge(address indexed sender, address indexed receiver, address indexed originalContractAddress, uint256 numTokens, string message, uint64 chainOrigin);
    event IssueLogBridge(address indexed sender, address indexed receiver, address indexed verificator, bytes32 transactionHash);
    event FeeCollected(address indexed sender, uint256 feeAmount);
    event FeesTransferred(address indexed to, uint256 amount);
    event ProtocolTransfer(address indexed sender, address indexed receiver, address indexed ERC20Tokens, uint256 numTokens);

    modifier onlyAccHaveAccess {
        require(msg.sender == owner || msg.sender == backupAddress || msg.sender == devOps || msg.sender == extension || msg.sender == developerWallet ||
                msg.sender == nodeOperator1 || msg.sender == nodeOperator2 || msg.sender == nodeOperator3, "Only authorized accounts can access this function");
        _;
    }

    modifier onlyProtocol {
        require(msg.sender == protocol || msg.sender == backupProtocol, "Only protocol address allowed");
        _;
    }
    

    constructor(address _developerWallet, address _backupAddress, address _devOps, address _extension,  uint256 _transactionFee) {
        owner = msg.sender;
        backupAddress = _backupAddress;
        devOps = _devOps;
        extension = _extension;
        developerWallet = _developerWallet;
        transactionFee = _transactionFee;
    }

    function getERC20Origin() external view returns (Origin [] memory){
        return ERC20TokenListOrigin;
    }

    function getERC20Foreign(address originalContractAddress) external view returns (Foreign [] memory){
        return ERC20TokenListForeign[originalContractAddress];
    }

    function getChain() external view returns (Chain [] memory){
        return chainList;
    }

    function addERC20Origin(address originalContractAddress) external onlyAccHaveAccess override returns (bool) {
        ERC20Origin[originalContractAddress] = Origin(originalContractAddress);
        ERC20TokenListOrigin.push(Origin(originalContractAddress));
        return true;
    }

    function addERC20Foreign(address originalContractAddress, address wrappedContractAddress, uint64 chainId) external onlyAccHaveAccess override returns (bool) {
        ERC20Foreign[originalContractAddress][chainId] = Foreign(originalContractAddress, wrappedContractAddress, chainId);
        ERC20TokenListForeign[originalContractAddress].push(Foreign(originalContractAddress, wrappedContractAddress, chainId));
        return true;
    }

    function addChain(uint64 chainID, string memory chainName) external onlyAccHaveAccess override returns (bool) {
        chainList.push(Chain(chainID, chainName));
        return true;
    }

    function sendBridge(address originalContractAddress, address receiver, uint256 numTokens, string memory message, uint64 chainDestination) external payable override nonReentrant returns (bool) {
        require(msg.value >= transactionFee, "Insufficient transaction fee");
        require(IERC20(originalContractAddress).allowance(msg.sender, address(this)) >= numTokens, "Not enough allowance to spend");
        require(IERC20(originalContractAddress).transferFrom(msg.sender, address(this), numTokens), "Token deposit transfer failed");
        
        collectedFees += msg.value;

        if(userERC20VestedPermit[msg.sender][originalContractAddress] == true){
            ERC20VestedBalance[originalContractAddress] += numTokens;
        }

        emit SendBridge(msg.sender, receiver, originalContractAddress, numTokens, message, chainDestination);
        emit FeeCollected(msg.sender, msg.value);

        return true;
    }
    
    function acceptBridge(bytes32 transactionHash, address sender, address receiver) external onlyAccHaveAccess override nonReentrant returns (bool) {
        // Developer related address cant receive anything.
        // Important safety for user to encourage user trust by limiting internal abuse of power
        require(receiver != owner || receiver != backupAddress || receiver != devOps || receiver != extension || receiver != developerWallet ||
                receiver != nodeOperator1 || receiver != nodeOperator2 || receiver != nodeOperator3, "Developer related cant receive anything");
        
        bytes32 trxLogs = transactionLogs[sender].transactionHash;
        bool verifyLogs = transactionLogs[sender].verify;
        require(transactionHash == trxLogs, "Invalid transaction logs");
        require(verifyLogs, "Transaction already proceed");

        transactionLogs[sender].verify = false;

        IERC20(ERC20Foreign[transactionLogs[sender].originalContractAddress][transactionLogs[sender].chainId].wrappedContractAddress).transfer(receiver, transactionLogs[sender].numTokens);

        emit AcceptBridge(msg.sender, receiver, transactionLogs[sender].originalContractAddress, transactionLogs[sender].numTokens, transactionLogs[sender].message, transactionLogs[sender].chainId);
        return true;
    }

    function issueLogBridge(address sender, address receiver, address originalContractAddress, bytes32 transactionHash, uint256 numTokens, string memory message, uint64 chainId) external onlyAccHaveAccess override returns (bool) {
        transactionLogs[sender] = Logs(receiver, originalContractAddress, transactionHash, numTokens, message, chainId, true);
        emit IssueLogBridge(sender, receiver, msg.sender, transactionHash);
        return true;
    }

    function regisERC20Vested(address ERC20Token) external onlyAccHaveAccess returns (bool){
        if(isVested[ERC20Token] == false){
            isVested[ERC20Token] = true;
        }
        else {
            isVested[ERC20Token] = false;
        }
        return true;
    }

    function regisERC20VestedPermit(address ERC20Token) external onlyAccHaveAccess returns (bool) {
        if(userERC20VestedPermit[msg.sender][ERC20Token] == false){
            userERC20VestedPermit[msg.sender][ERC20Token] = true;
        }
        else {
            userERC20VestedPermit[msg.sender][ERC20Token] = false;
        }
        return true;
    }

    function protocolERC20Receive(address ERC20Token, address sender, uint256 numTokens) external onlyProtocol override nonReentrant returns (bool) {
        require(IERC20(ERC20Token).allowance(sender, address(this)) >= numTokens, "Not enough allowance to spend");
        require(IERC20(ERC20Token).transferFrom(sender, address(this), numTokens), "Token transfer failed");

        ERC20VestedBalance[ERC20Token] += numTokens;

        emit ProtocolTransfer(sender, address(this), ERC20Token, numTokens);

        return true;
    }

    function protocolERC20Transfer(address ERC20Token, address destination, uint256 numTokens) external onlyProtocol override nonReentrant returns (bool) {
        require(isVested[ERC20Token] == true, "ERC20 token is not vested");
        require(ERC20VestedBalance[ERC20Token] >= numTokens, "Not enough vested tokens to provide");
        require(IERC20(ERC20Token).balanceOf(address(this)) >= numTokens, "Not enough tokens balance in contract");

        ERC20VestedBalance[ERC20Token] -= numTokens;

        IERC20(ERC20Token).transfer(destination, numTokens);

        emit ProtocolTransfer(address(this), destination, ERC20Token, numTokens);

        return true;
    }

    function transferCollectedFees() external onlyAccHaveAccess nonReentrant returns (bool) {
        uint256 feeAmount = collectedFees;
        require(feeAmount > 0, "No fees to transfer");

        (bool success, ) = developerWallet.call{value: feeAmount}("");
        require(success, "Fee transfer failed");

        collectedFees = 0;
        emit FeesTransferred(developerWallet, feeAmount);
        return true;
    }

    function updateTransactionFee(uint256 newFee) external onlyAccHaveAccess returns (bool) {
        transactionFee = newFee;
        return true;
    }

    function updateDeveloperWallet(address newDeveloperWallet) external onlyAccHaveAccess returns (bool) {
        developerWallet = newDeveloperWallet;
        return true;
    }

    function updateBackupAddress(address newBackupAddress) external onlyAccHaveAccess returns (bool) {
        backupAddress = newBackupAddress;
        return true;
    }

    function updateDevOps(address newDevOps) external onlyAccHaveAccess returns (bool) {
        devOps = newDevOps;
        return true;
    }

    function updateExtension(address newExtension) external onlyAccHaveAccess returns (bool) {
        extension = newExtension;
        return true;
    }

    function updateOwner(address newOwner) external onlyAccHaveAccess returns (bool) {
        owner = newOwner;
        return true;
    }

    function updateNodeOperator(address operator1, address operator2, address operator3) external onlyAccHaveAccess returns (bool) {
        nodeOperator1 = operator1;
        nodeOperator2 = operator2;
        nodeOperator3 = operator3;
        return true;
    }

    function updateProtocolAddress(address newProtocol, address newBackupProtocol) external onlyAccHaveAccess returns (bool) {
        protocol = newProtocol;
        backupProtocol = newBackupProtocol;
        return true;
    }
}
