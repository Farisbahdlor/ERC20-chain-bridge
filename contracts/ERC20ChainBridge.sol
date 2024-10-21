// SPDX-License-Identifier: GTC-Protocol-1.0
pragma solidity 0.8.27;

import "../interfaces/IERC20.sol";
import "../interfaces/IChainBridge.sol";
import "../interfaces/ISmartContractSync.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ERC20ChainBridge is IChainBridge, ReentrancyGuard {

    struct Foreign {
        address originalContractAddress;
        address wrappedContractAddress;
        uint64 chainId;
        bool check;
    }

    struct Chain {
        uint64 chainId;
        string chainName;
    }

    struct UserVested {
        bool vested;
        uint256 startTime;
        uint256 endTime;
    }

    mapping (address => bool) public ERC20Origin;
    // PoT is Proof of Token Note that proof the ownership of real underlying ERC20 asset
    // that current token pool are being collateralized to facilitate financial service (loans, borrow, swap, etc).
    mapping (address => address) public ERC20OriginPoT;
    mapping (address => mapping (uint64 => Foreign)) public ERC20Foreign;
    mapping (address => Foreign[]) public ERC20TokenListForeign;
    mapping (uint64 => bool) public chain;
    mapping (address => bool vested) public isVested;
    mapping (address => mapping (address => UserVested)) public userERC20VestedPermit;
    mapping (address => uint256) public ERC20VestedBalance;
    address[] public ERC20TokenListOrigin;
    Chain[] public chainList;

    uint256 public collectedFees;

    // Owner and developer-related addresses
    mapping (address => bool) public whitelistAddress;
    address public owner;
    address public backupAddress;
    address public hotWallet;

    // Extended protocol address
    mapping (address => bool) public protocolAddress;
    
    uint256 public transactionFee;  // Fee in base token for each transaction

    event SendBridge(address indexed sender, address indexed receiver, address indexed originalContractAddress, address smartContractSync, uint256 numTokens, string message, uint64 chainDestination);
    event AcceptBridge(address indexed sender, address indexed receiver, address indexed originalContractAddress, uint256 numTokens, string message, uint64 chainOrigin);
    event FeeCollected(address indexed sender, uint256 feeAmount);
    event FeesTransferred(address indexed to, uint256 amount);
    event ProtocolTransfer(address indexed sender, address indexed receiver, address indexed ERC20Tokens, uint256 numTokens);
    event SmartContractSync(address indexed sender, address indexed receiver, address  originalContractAddress, address indexed smartContractSync, address wrappedContractAddress, uint256 numTokens, string message, uint64 chainId);

    modifier onlyOwnerAccess {
        require(owner == msg.sender || backupAddress == msg.sender,"Only owner address have access");
        _;
    }
    
    modifier onlyProtocolAccess {
        require(protocolAddress[msg.sender], "Only listed protocol address");
        _;
    }

    modifier onlyWhitelistAccess {
        require(whitelistAddress[msg.sender],"Only white listed address");
        _;
    }
    

    constructor(address _backupAddress, address _hotWallet, uint256 _transactionFee) {
        owner = msg.sender;
        backupAddress = _backupAddress;
        transactionFee = _transactionFee;
        hotWallet = _hotWallet;
    }

    function getERC20Origin() external view returns (address [] memory){
        return ERC20TokenListOrigin;
    }

    function getERC20Foreign(address originalContractAddress) external view returns (Foreign [] memory){
        return ERC20TokenListForeign[originalContractAddress];
    }

    function getChain() external view returns (Chain [] memory){
        return chainList;
    }

    function checkERC20OriginAvailable(address ERC20Token) external view returns (bool){
        return ERC20Origin[ERC20Token];
    }

    function checkERC20ForeignAvailable(address originalContractAddress, uint64 chainId) external view returns (bool){
        return ERC20Foreign[originalContractAddress][chainId].check;
    }

    function checkChainAvailable(uint64 chainID) external view returns (bool){
        return chain[chainID];
    }

    function checkERC20VestedBalance(address ERC20Token) external view returns (uint256) {
        require(ERC20Origin[ERC20Token], "Token not from origin chain");
        return ERC20VestedBalance[ERC20Token];
    }

    function addERC20Origin(address originalContractAddress) external onlyOwnerAccess override returns (bool) {
        if(ERC20Origin[originalContractAddress] == false){
            ERC20Origin[originalContractAddress] = true;
            ERC20TokenListOrigin.push(originalContractAddress);
            return true;
        }
        return false;
    }

    function updateERC20OriginPoT(address originalContractAddress, address PoTContractAddress) external onlyOwnerAccess override returns (bool) {
        if(ERC20Origin[originalContractAddress] == true){
            ERC20OriginPoT[originalContractAddress] = PoTContractAddress;
            return true;
        }
        return false;
    }

    function addERC20Foreign(address originalContractAddress, address wrappedContractAddress, uint64 chainId) external onlyOwnerAccess override returns (bool) {
        if(ERC20Foreign[originalContractAddress][chainId].check == false){
            ERC20Foreign[originalContractAddress][chainId] = Foreign(originalContractAddress, wrappedContractAddress, chainId, true);
            ERC20TokenListForeign[originalContractAddress].push(Foreign(originalContractAddress, wrappedContractAddress, chainId, true));
            return true;
        }
        return false;
    }

    function addChain(uint64 chainID, string memory chainName) external onlyOwnerAccess override returns (bool) {
        if(chain[chainID] == false){
            chain[chainID] = true;
            chainList.push(Chain(chainID, chainName));
            return true;
        }
        return false;
    }

    function updateChain(uint64 chainID) external onlyOwnerAccess returns (bool){
        if(chain[chainID] == true){
            chain[chainID] = false;
        }
        else {
            chain[chainID] = true;
        }
        return true;
    }    
     
    function batchSendBridge(
        address[] memory originalContractAddress, 
        address[] memory sender,
        address[] memory receiver, 
        address[] memory smartContractSync, 
        uint256[] memory numTokens, 
        string[] memory message, 
        uint64[] memory chainDestination
    ) 
        external payable nonReentrant returns (bool) {
        // Ensure all input arrays have the same length
        require(
            originalContractAddress.length == receiver.length &&
            receiver.length == smartContractSync.length &&
            smartContractSync.length == numTokens.length &&
            numTokens.length == message.length &&
            message.length == chainDestination.length,
            "Input arrays must have the same length"
        );

        uint256 batchLength = originalContractAddress.length;
        uint256 totalFee = 0;

        // Loop through each transaction in the batch
        for (uint32 i = 0; i < batchLength; i++) {
            // Ensure the destination chain is supported
            require(chain[chainDestination[i]], string(abi.encodePacked("Chain service not available at index: ", Strings.toString(i))));

            address _sender = sender[i];
            address _receiver = receiver[i];
            address _originalContractAddress = originalContractAddress[i];
            address _smartContractSync = smartContractSync[i];
            uint256 _numTokens = numTokens[i];
            string memory _message = message[i];
            uint64 _chainDestination = chainDestination[i];

            // Ensure valid contract and receiver addresses
            require(_originalContractAddress != address(0), string(abi.encodePacked("ERC20 token address not found at index: ", Strings.toString(i))));
            require(_receiver != address(0), string(abi.encodePacked("Receiver address not found at index: ", Strings.toString(i))));

            uint256 endTime = userERC20VestedPermit[_sender][_originalContractAddress].endTime;
            uint256 startTime = userERC20VestedPermit[_sender][_originalContractAddress].startTime;

            // Calculate vested duration
            uint256 vestedDuration = endTime - startTime;

            // Ensure block.timestamp is less than or equal to endTime to prevent underflow
            uint256 remainingTime = (block.timestamp > endTime) ? 0 : (endTime - block.timestamp);

            // Check if remaining time is at least 1/3 of the vested duration
            bool validVestedDuration = remainingTime >= (vestedDuration / 3);

            // Handle free transaction fee for vested users
            if (userERC20VestedPermit[_sender][_originalContractAddress].vested && validVestedDuration && ERC20Origin[_originalContractAddress]) {   
                ERC20VestedBalance[_originalContractAddress] += _numTokens;
            } else {
                totalFee += transactionFee;
            }

            // Ensure the sender has given enough allowance for the token transfer
            require(IERC20(_originalContractAddress).allowance(_sender, address(this)) >= _numTokens, string(abi.encodePacked("Not enough allowance to spend at index: ", Strings.toString(i))));
            
            // Perform the token transfer from the sender to the contract
            require(IERC20(_originalContractAddress).transferFrom(_sender, address(this), _numTokens), string(abi.encodePacked("Token deposit transfer failed at index: ", Strings.toString(i))));

            // Emit event for each individual transaction in the batch
            emit SendBridge(_sender, _receiver, _originalContractAddress, _smartContractSync, _numTokens, _message, _chainDestination);
        }

        // Handle the transaction fee for non-vested users
        if (totalFee > 0) {
            require(msg.value >= totalFee, string(abi.encodePacked("Insufficient total transaction fee, fee required:", Strings.toString(totalFee))));
            collectedFees += totalFee;
            emit FeeCollected(msg.sender, totalFee);
        }

        return true;
    }


    function sendBridge(address originalContractAddress, address receiver, address smartContractSync, uint256 numTokens, string memory message, uint64 chainDestination) external payable override nonReentrant returns (bool) {
        require(chain[chainDestination], "Chain service not available");
        require(originalContractAddress != address(0), "ERC20 token address not found");
        require(receiver != address(0), "Receiver address not found");
        
        uint256 endTime = userERC20VestedPermit[msg.sender][originalContractAddress].endTime;
        uint256 startTime = userERC20VestedPermit[msg.sender][originalContractAddress].startTime;

        // Calculate vested duration
        uint256 vestedDuration = endTime - startTime;

        // Ensure block.timestamp is less than or equal to endTime to prevent underflow
        uint256 remainingTime = (block.timestamp > endTime) ? 0 : (endTime - block.timestamp);

        // Check if remaining time is at least 1/3 of the vested duration
        bool validVestedDuration = remainingTime >= (vestedDuration / 3);

        // Handle free transaction fee for vested users
        if (userERC20VestedPermit[msg.sender][originalContractAddress].vested && validVestedDuration && ERC20Origin[originalContractAddress]) {   
            ERC20VestedBalance[originalContractAddress] += numTokens;
        }
        else {
            require(msg.value >= transactionFee, "Insufficient transaction fee");
            collectedFees = collectedFees + msg.value;
            emit FeeCollected(msg.sender, msg.value);
            return true;
        }
        require(IERC20(originalContractAddress).allowance(msg.sender, address(this)) >= numTokens, "Not enough allowance to spend");
        require(IERC20(originalContractAddress).transferFrom(msg.sender, address(this), numTokens), "Token deposit transfer failed");

        emit SendBridge(msg.sender, receiver, originalContractAddress, smartContractSync, numTokens, message, chainDestination);

        return true;
    }

    function batchAcceptBridge(
        address[] memory sender,
        address[] memory receiver,
        address[] memory originalContractAddress,
        address[] memory smartContractSync,
        uint256[] memory numTokens,
        string[] memory message,
        uint64[] memory chainId
    ) external override onlyWhitelistAccess onlyProtocolAccess returns (bool) {
        require(
            sender.length == receiver.length &&
            receiver.length == originalContractAddress.length &&
            originalContractAddress.length == numTokens.length &&
            numTokens.length == message.length &&
            message.length == chainId.length,
            "Input arrays must have the same length"
        );

        uint256 batchLength = sender.length;
        for (uint32 i = 0; i < batchLength; i++) {
            address wrappedContractAddress = ERC20Foreign[originalContractAddress[i]][chainId[i]].wrappedContractAddress;
            
            uint256 endTime = userERC20VestedPermit[sender[i]][originalContractAddress[i]].endTime;

            // Check Vested Duration
            bool checkVestedDuration = endTime < block.timestamp;
            
            if(userERC20VestedPermit[receiver[i]][originalContractAddress[i]].vested && ERC20Origin[wrappedContractAddress]){
                if(ERC20VestedBalance[wrappedContractAddress] < numTokens[i] || checkVestedDuration){
                    wrappedContractAddress = ERC20OriginPoT[wrappedContractAddress];
                    require(wrappedContractAddress != address(0), string(abi.encodePacked("Wrapped contract address not found at index: ", Strings.toString(i))));
                    require(IERC20(wrappedContractAddress).transfer(receiver[i], numTokens[i]), "Transfer failed");
                }
                else {
                    ERC20VestedBalance[wrappedContractAddress] -= numTokens[i];
                    require(wrappedContractAddress != address(0), string(abi.encodePacked("Wrapped contract address not found at index: ", Strings.toString(i))));
                    require(IERC20(wrappedContractAddress).transfer(receiver[i], numTokens[i]), string(abi.encodePacked("Transfer failed at index: ", Strings.toString(i))));
                }
            }
            else {
                require(wrappedContractAddress != address(0), string(abi.encodePacked("Wrapped contract address not found at index: ", Strings.toString(i))));
                require(IERC20(wrappedContractAddress).transfer(receiver[i], numTokens[i]), string(abi.encodePacked("Transfer failed at index: ", Strings.toString(i))));
            }

            if (smartContractSync[i] != address(0)) {
                if(ISmartContractSync(smartContractSync[i]).ERC20DataSync(sender[i], receiver[i], originalContractAddress[i], wrappedContractAddress, numTokens[i], message[i], chainId[i]))
                emit SmartContractSync(sender[i], receiver[i], smartContractSync[i], originalContractAddress[i], wrappedContractAddress, numTokens[i], message[i], chainId[i]);
                else revert(string(abi.encodePacked("Smart contract sync failed at index: ", Strings.toString(i))));
            }

            emit AcceptBridge(sender[i], receiver[i], originalContractAddress[i], numTokens[i], message[i], chainId[i]);
        }

        return true;
    }
    
    function acceptBridge(address sender, address receiver, address originalContractAddress, address smartContractSync, uint256 numTokens, string memory message, uint64 chainId) external override onlyWhitelistAccess onlyProtocolAccess returns (bool) {
        address wrappedContractAddress = ERC20Foreign[originalContractAddress][chainId].wrappedContractAddress;
        uint256 endTime = userERC20VestedPermit[sender][originalContractAddress].endTime;

        // Check Vested Duration
        bool checkVestedDuration = endTime < block.timestamp;
        if(userERC20VestedPermit[receiver][originalContractAddress].vested && ERC20Origin[wrappedContractAddress]){
            if(ERC20VestedBalance[wrappedContractAddress] < numTokens || checkVestedDuration){
                wrappedContractAddress = ERC20OriginPoT[wrappedContractAddress];
                require(wrappedContractAddress != address(0), "Wrapped contract address not found");
                require(IERC20(wrappedContractAddress).transfer(receiver, numTokens), "Transfer failed");
            }
            else {
                ERC20VestedBalance[wrappedContractAddress] -= numTokens;
                require(wrappedContractAddress != address(0), "Wrapped contract address not found");
                require(IERC20(wrappedContractAddress).transfer(receiver, numTokens), "Transfer failed");
            }
            
        }
        else {            
            require(wrappedContractAddress != address(0), "Wrapped contract address not found");
            require(IERC20(wrappedContractAddress).transfer(receiver, numTokens), "Transfer failed");
        }

        if (smartContractSync != address(0)) {
            if(ISmartContractSync(smartContractSync).ERC20DataSync(sender, receiver, originalContractAddress, wrappedContractAddress, numTokens, message, chainId))
            emit SmartContractSync(sender, receiver, smartContractSync, originalContractAddress, wrappedContractAddress, numTokens, message, chainId);
        }

        emit AcceptBridge(sender, receiver, originalContractAddress, numTokens, message, chainId);
        return true;
    }

    function redeemERC20PoT(address ownerPoT, address ERC20Token, uint256 numTokens) external override returns (bool) {
        require(isVested[ERC20Token], "Token is not vested");
        uint256 currentVestedBalance = ERC20VestedBalance[ERC20Token]; 
        require(userERC20VestedPermit[ownerPoT][ERC20Token].endTime < block.timestamp, "User still in vested lock duration");
        require(numTokens <= currentVestedBalance, "Not enough vested tokens to provide");
        
        ERC20VestedBalance[ERC20Token] = currentVestedBalance - numTokens; 
        require(IERC20(ERC20Token).allowance(ownerPoT, address(this)) >= numTokens, "Not enough allowance to spend");
        require(IERC20(ERC20Token).transferFrom(ownerPoT, address(this), numTokens), "Token transfer failed");
        require(IERC20(ERC20Token).transfer(ownerPoT, numTokens), "Redeem transfer failed"); 
        
        emit ProtocolTransfer(address(this), ownerPoT, ERC20Token, numTokens); 
        return true; 
    }

    function updateERC20Vested(address ERC20Token) external onlyWhitelistAccess returns (bool){
        require(ERC20Origin[ERC20Token], "Token not from origin chain");
        if(isVested[ERC20Token] == false){
            isVested[ERC20Token] = true;
        }
        else {
            isVested[ERC20Token] = false;
        }
        return true;
    }

    function updateERC20VestedPermit(address ERC20Token, uint8 vestedDuration) external returns (bool) {
        // vested duration option for 3 month, 6 month, and 12 month.
        if(isVested[ERC20Token] = true){
            if(userERC20VestedPermit[msg.sender][ERC20Token].vested == false || userERC20VestedPermit[msg.sender][ERC20Token].endTime > block.timestamp){
                if(vestedDuration == 3){
                    uint256 startTime = block.timestamp;
                    uint256 endTime = block.timestamp + (3 * (30 * 24 * 60 *60));
                    userERC20VestedPermit[msg.sender][ERC20Token] = UserVested(true, startTime, endTime); 
                }
                else if (vestedDuration == 6){
                    uint256 startTime = block.timestamp;
                    uint256 endTime = block.timestamp + (6 * (30 * 24 * 60 *60));
                    userERC20VestedPermit[msg.sender][ERC20Token] = UserVested(true, startTime, endTime);
                }
                else if (vestedDuration == 12){
                    uint256 startTime = block.timestamp;
                    uint256 endTime = block.timestamp + (12 * (30 * 24 * 60 *60));
                    userERC20VestedPermit[msg.sender][ERC20Token] = UserVested(true, startTime, endTime);
                }
                else revert("Vested duration not match");
            }
            else if(userERC20VestedPermit[msg.sender][ERC20Token].endTime < block.timestamp){
                userERC20VestedPermit[msg.sender][ERC20Token].vested = false;
            }
        }
        else {
            revert("ERC20 token is not registered as vested");
        }
        return true;
    }

    function protocolERC20Receive(address ERC20Token, address sender, uint256 numTokens) external override onlyProtocolAccess nonReentrant returns (bool) {
        require(isVested[ERC20Token] == true, "ERC20 token is not vested");
        require(IERC20(ERC20Token).allowance(sender, address(this)) >= numTokens, "Not enough allowance to spend");
        require(IERC20(ERC20Token).transferFrom(sender, address(this), numTokens), "Token transfer failed");

        ERC20VestedBalance[ERC20Token] = ERC20VestedBalance[ERC20Token] + numTokens;

        emit ProtocolTransfer(sender, address(this), ERC20Token, numTokens);

        return true;
    }

    function protocolERC20Transfer(address ERC20Token, address destination, uint256 numTokens) external override onlyProtocolAccess nonReentrant returns (bool) {
        require(isVested[ERC20Token] == true, "ERC20 token is not vested");
        require(ERC20VestedBalance[ERC20Token] >= numTokens, "Not enough vested tokens to provide");
        require(IERC20(ERC20Token).balanceOf(address(this)) >= numTokens, "Not enough tokens balance in contract");

        ERC20VestedBalance[ERC20Token] = ERC20VestedBalance[ERC20Token] - numTokens;

        IERC20(ERC20Token).transfer(destination, numTokens);

        emit ProtocolTransfer(address(this), destination, ERC20Token, numTokens);

        return true;
    }

    function transferCollectedFees() external onlyOwnerAccess nonReentrant returns (bool) {
        uint256 feeAmount = collectedFees;
        require(feeAmount != 0, "No fees to transfer");

        (bool success, ) = hotWallet.call{value: feeAmount}("");
        require(success, "Fee transfer failed");

        collectedFees = 0;
        emit FeesTransferred(hotWallet, feeAmount);
        return true;
    }

    function updateTransactionFee(uint256 newFee) external onlyOwnerAccess returns (bool) {
        transactionFee = newFee;
        return true;
    }

    function updateWhiteListAddress(address newWhiteListAddress) external onlyOwnerAccess returns (bool) {
        if(whitelistAddress[newWhiteListAddress] == false){
            whitelistAddress[newWhiteListAddress] = true;
        }
        else {
            whitelistAddress[newWhiteListAddress] = false;
        }
        return true;
    }

    function updateOwnerAddress(address newOwnerAddress) external onlyOwnerAccess returns (bool) {
        owner = newOwnerAddress;
        return true;
    }

    function updateBackupAddress(address newBackupAddress) external onlyOwnerAccess returns (bool) {
        backupAddress = newBackupAddress;
        return true;
    }

    function updateProtocolAddress(address newProtocolAddress) external onlyOwnerAccess returns (bool) {
        if(protocolAddress[newProtocolAddress] == false){
            protocolAddress[newProtocolAddress] = true;
        }
        else {
            protocolAddress[newProtocolAddress] = false;
        }
        return true;
    }
}
