package config

import (
	"fmt"

	"github.com/spf13/viper"
)

type Config struct {
	EthereumRPC             string
	ArbitrumRPC             string
	OptimismRPC             string
	BSCMainnetRPC           string
	BaseMainnetRPC          string
	EthereumChainID         int
	ArbitrumChainID         int
	OptimismChainID         int
	BSCChainID              int
	BaseChainID             int
	ContractAddressEthereum string
	ContractAddressArbitrum string
	ContractAddressOptimism string
	ContractAddressBSC      string
	ContractAddressBase     string
	PrivateKey              string
	PostgresDSN             string
}

func LoadConfig() (*Config, error) {
	viper.SetConfigFile(".env")
	err := viper.ReadInConfig()
	if err != nil {
		return nil, fmt.Errorf("Error reading config file: %v", err)
	}

	return &Config{
		EthereumRPC:             viper.GetString("ETHEREUM_RPC"),
		ArbitrumRPC:             viper.GetString("ARBITRUM_RPC"),
		OptimismRPC:             viper.GetString("OPTIMISM_RPC"),
		BSCMainnetRPC:           viper.GetString("BSC_MAINNET_RPC"),
		BaseMainnetRPC:          viper.GetString("BASE_MAINNET_RPC"),
		EthereumChainID:         viper.GetInt("ETHEREUM_CHAIN_ID"),
		ArbitrumChainID:         viper.GetInt("ARBITRUM_CHAIN_ID"),
		OptimismChainID:         viper.GetInt("OPTIMISM_CHAIN_ID"),
		BSCChainID:              viper.GetInt("BSC_CHAIN_ID"),
		BaseChainID:             viper.GetInt("BASE_CHAIN_ID"),
		ContractAddressEthereum: viper.GetString("ETHEREUM_CONTRACT"),
		ContractAddressArbitrum: viper.GetString("ARBITRUM_CONTRACT"),
		ContractAddressOptimism: viper.GetString("OPTIMISM_CONTRACT"),
		ContractAddressBSC:      viper.GetString("BSC_MAINNET_CONTRACT"),
		ContractAddressBase:     viper.GetString("BASE_MAINNET_CONTRACT"),
		PrivateKey:              viper.GetString("PRIVATE_KEY"),
		PostgresDSN:             viper.GetString("POSTGRES_DSN"),
	}, nil
}

// func LoadConfig() (*Config, error) {
// 	viper.SetConfigType("env")
// 	viper.AddConfigPath(".")
// 	viper.AutomaticEnv()

// 	if err := viper.ReadInConfig(); err != nil {
// 		return nil, err
// 	}

// 	config := &Config{
// 		EthereumRPC:     viper.GetString("ETHEREUM_RPC"),
// 		ArbitrumRPC:     viper.GetString("ARBITRUM_RPC"),
// 		OptimismRPC:     viper.GetString("OPTIMISM_RPC"),
// 		BSCMainnetRPC:   viper.GetString("BSC_MAINNET_RPC"),
// 		BaseMainnetRPC:  viper.GetString("BASE_MAINNET_RPC"),
// 		ContractAddress: viper.GetString("CONTRACT_ADDRESS"),
// 		PrivateKey:      viper.GetString("PRIVATE_KEY"),
// 		PostgresDSN:     viper.GetString("POSTGRES_DSN"),
// 	}

// 	update this part accordingly to the new updated Config struct.

// 	return config, nil
// }
