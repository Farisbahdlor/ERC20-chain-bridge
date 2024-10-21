// SPDX-License-Identifier: GTC-Protocol-1.0
pragma solidity 0.8.27;

interface IChainBridge {

    function checkERC20OriginAvailable(address ERC20Token) external view returns (bool);
    function checkERC20ForeignAvailable(address originalContractAddress, uint64 chainId) external view returns (bool);
    function checkChainAvailable(uint64 chainID) external view returns (bool);
    function checkERC20VestedBalance(address ERC20Token) external view returns (uint256);
    function addERC20Origin(address originalContractAddress) external returns (bool);
    function updateERC20OriginPoT(address originalContractAddress, address PoTContractAddress) external returns (bool);
    function addERC20Foreign(address originalContractAddress, address wrappedContractAddress, uint64 chainId) external returns (bool);
    function addChain(uint64 chainID, string memory chainName) external returns (bool);
    function batchSendBridge(address [] memory originalContractAddress, address[] memory sender, address [] memory receiver, address [] memory smartContractSync, uint256 [] memory numTokens, string [] memory message, uint64 [] memory chainDestination) external payable returns (bool);
    function sendBridge(address originalContractAddress, address receiver, address smartContractSync, uint256 numTokens, string memory message, uint64 chainDestination) external payable returns (bool);
    function batchAcceptBridge(address [] memory sender, address [] memory receiver, address [] memory originalContractAddress, address[] memory smartContractSync, uint256 [] memory numTokens, string [] memory message, uint64 [] memory chainId) external returns (bool);
    function acceptBridge(address sender, address receiver, address originalContractAddress, address smartContractSync, uint256 numTokens, string memory message, uint64 chainId) external returns (bool);
    function redeemERC20PoT(address ownerPoT, address ERC20Token, uint256 numTokens) external returns (bool);
    function protocolERC20Transfer(address ERC20Token, address destination, uint256 numTokens) external returns (bool);
    function protocolERC20Receive(address ERC20Token, address sender, uint256 numTokens) external returns (bool);
}
