// SPDX-License-Identifier: GTC-Protocol-1.0
pragma solidity 0.8.27;

interface IChainBridge {

    function addERC20Origin(address originalContractAddress) external returns (bool);
    function addERC20Foreign(address originalContractAddress, address wrappedContractAddress, uint64 chainId) external returns (bool);
    function addChain(uint64 chainID, string memory chainName) external returns (bool);
    function sendBridge(address originalContractAddress, address receiver, uint256 numTokens, string memory message, uint64 chainDestination) external payable returns (bool);
    function acceptBridge(bytes32 transactionHash, address sender, address receiver) external returns (bool);
    function issueLogBridge(address sender, address receiver, address originalContractAddress, bytes32 transactionHash, uint256 numTokens, string memory message, uint64 chainId) external returns (bool);
    function protocolERC20Transfer(address ERC20Token, address destination, uint256 numTokens) external returns (bool);
    function protocolERC20Receive(address ERC20Token, address sender, uint256 numTokens) external returns (bool);
    

    // function addERC20Origin (address originalContractAddress) external returns (bool);
    // function addERC20Foreign (address originalContractAddress, address wrappedContractAddress, uint64 chainId) external returns (bool);
    // function sendbridge(address originalContractAddress, uint256 numTokens, string memory message, uint64 chainDestination) external returns (bool);
    // function acceptBridge(string memory transactionHash) external returns (bool);
    // function issueLogBridge(address user, address originalContractAddress, string memory transactionHash, uint256 numTokens, string memory message, uint64 chainId) external returns (bool);
    
}