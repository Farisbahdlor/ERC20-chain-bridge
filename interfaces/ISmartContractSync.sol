// SPDX-License-Identifier: GTC-Protocol-1.0
pragma solidity 0.8.27;

interface ISmartContractSync {

    function ERC20DataSync(address sender, address receiver, address originalContractAddress, address wrappedContractAddress, uint256 numTokens, string memory message, uint64 chainId) external returns (bool);
}
