package services

import (
	"base-mainnet/config"
	"base-mainnet/models"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"gorm.io/gorm"
)

type Event struct {
	Sender           common.Address
	Receiver         common.Address
	OriginalContract common.Address
	NumTokens        *big.Int
	Message          string
	ChainDestination uint64
}

// Instantiate the smart contract
func NewChainBridgeInstance(contractAddress common.Address, client *ethclient.Client) (*bind.BoundContract, error) {
	// Load the ABI from the chainBridgeABI.json file
	abiData, err := os.ReadFile("contracts/chainBridgeABI.json")
	if err != nil {
		return nil, fmt.Errorf("failed to read ABI file: %v", err)
	}

	parsedABI, err := abi.JSON(strings.NewReader(string(abiData)))
	if err != nil {
		return nil, fmt.Errorf("failed to parse ABI: %v", err)
	}

	// Create a bound contract instance
	contract := bind.NewBoundContract(contractAddress, parsedABI, client, client, client)
	return contract, nil
}

func ListenChain(ctx context.Context, rpcURL string, contractAddress common.Address, db *gorm.DB, chainID int, cfg *config.Config) {
	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		log.Fatalf("Failed to connect to the Ethereum client: %v", err)
	}

	// Load the ABI from the chainBridgeABI.json file
	abiData, err := os.ReadFile("contracts/chainBridgeABI.json")
	if err != nil {
		log.Fatalf("Failed to read ABI file: %v", err)
	}

	// Ensure the ABI JSON is unmarshalled into a slice of structs
	var abiJSON []map[string]interface{}
	err = json.Unmarshal(abiData, &abiJSON)
	if err != nil {
		log.Fatalf("Failed to unmarshal ABI JSON: %v", err)
	}

	contractABI, err := abi.JSON(strings.NewReader(string(abiData)))
	if err != nil {
		log.Fatalf("Failed to parse contract ABI: %v", err)
	}

	query := ethereum.FilterQuery{
		Addresses: []common.Address{contractAddress},
	}

	logs := make(chan types.Log)
	sub, err := client.SubscribeFilterLogs(ctx, query, logs)
	if err != nil {
		log.Fatalf("Failed to subscribe to logs: %v %d", err, chainID)
	}

	for {
		select {
		case err := <-sub.Err():
			log.Printf("Error: %v", err)
		case vLog := <-logs:

			event := Event{}

			eventSignature := "SendBridge(address,address,address,uint256,string,uint64)"
			hash := crypto.Keccak256Hash([]byte(eventSignature))
			eventSignatureHash := hash.Hex()

			if vLog.Topics[0].Hex() != eventSignatureHash {
				log.Printf("event signature mismatch: expected %s, got %s", eventSignatureHash, vLog.Topics[0].Hex())
				continue
			}

			err := contractABI.UnpackIntoInterface(&event, "SendBridge", vLog.Data)
			if err != nil {
				log.Printf("Error unpacking event data: %v", err)
				continue
			}
			event.Sender = common.HexToAddress(vLog.Topics[1].Hex())
			event.Receiver = common.HexToAddress(vLog.Topics[2].Hex())
			event.OriginalContract = common.HexToAddress(vLog.Topics[3].Hex())

			log.Printf("vLog Data Length: %d", len(vLog.Data))
			log.Printf("vLog Data: %v", vLog.Data)

			// Process the event data
			log.Printf("Sender: %s\n", event.Sender.Hex())
			log.Printf("Receiver: %s\n", event.Receiver.Hex())
			log.Printf("OriginalContract: %s\n", event.OriginalContract.Hex())
			log.Printf("NumTokens: %s\n", event.NumTokens.String())
			log.Printf("Message: %s\n", event.Message)
			log.Printf("ChainDestination: %d\n", event.ChainDestination)

			log.Printf("Upcoming Event: %v", event)

			transaction := models.Transaction{
				Sender:           event.Sender.Hex(),
				Receiver:         event.Receiver.Hex(),
				OriginalContract: event.OriginalContract.Hex(),
				NumTokens:        event.NumTokens.String(),
				ChainID:          big.NewInt(int64(chainID)).String(),
				TransactionHash:  vLog.TxHash.Hex(),
				Status:           "Pending",
				Message:          event.Message,
			}

			log.Printf("Upcoming Trasaction: %v", transaction)
			if err := db.Create(&transaction).Error; err != nil {
				log.Printf("Error saving user data to database: %v", err)
			}

			var nonce models.Nonce
			if err := db.Where("address = ?", contractAddress.Hex()).First(&nonce).Error; err != nil {
				log.Printf("Failed to get nonce from DB: %v", err)
			}
			nonce.Nonce += 2

			db.Where("address = ?", contractAddress.Hex()).Save(&nonce)

			ProcessTransaction(contractABI, event, transaction, event.ChainDestination, db, cfg)

		}
	}
}

func ProcessTransaction(contractABI abi.ABI, event Event, transaction models.Transaction, chainID uint64, db *gorm.DB, cfg *config.Config) {
	privateKey, err := crypto.HexToECDSA(cfg.PrivateKey)
	if err != nil {
		log.Fatalf("Failed to load private key: %v", err)
	}

	uintChainID := big.NewInt(int64(chainID))

	auth, err := bind.NewKeyedTransactorWithChainID(privateKey, uintChainID)
	if err != nil {
		log.Fatalf("Failed to create transaction auth: %v", err)
	}

	// Determine the contract address based on the chainID
	var contractAddress string
	var rpcURL string
	switch event.ChainDestination {
	case uint64(cfg.EthereumChainID):
		contractAddress = cfg.ContractAddressEthereum
		rpcURL = cfg.EthereumRPC
	case uint64(cfg.ArbitrumChainID):
		contractAddress = cfg.ContractAddressArbitrum
		rpcURL = cfg.ArbitrumRPC
	case uint64(cfg.OptimismChainID):
		contractAddress = cfg.ContractAddressOptimism
		rpcURL = cfg.OptimismRPC
	case uint64(cfg.BSCChainID):
		contractAddress = cfg.ContractAddressBSC
		rpcURL = cfg.BSCMainnetRPC
	case uint64(cfg.BaseChainID):
		contractAddress = cfg.ContractAddressBase
		rpcURL = cfg.BaseMainnetRPC
	default:
		log.Fatalf("Unsupported chain ID: %v", event.ChainDestination)
	}

	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		log.Fatalf("Failed to connect to the Ethereum client: %v", err)
	}

	instance, err := NewChainBridgeInstance(common.HexToAddress(contractAddress), client)
	if err != nil {
		log.Fatalf("Failed to instantiate contract: %v", err)
	}

	var trxHash [32]byte
	// Convert the string to a byte slice
	byteSlice := []byte(transaction.TransactionHash)
	// Ensure that the string fits into the [32]byte array
	if len(byteSlice) > 32 {
		byteSlice = byteSlice[:32]
	}
	// Copy the byte slice into the [32]byte array
	copy(trxHash[:], byteSlice)

	// Encode the method call with arguments
	callData, err := contractABI.Pack("issueLogBridge", event.Sender, event.Receiver, event.OriginalContract, trxHash, event.NumTokens, event.Message, event.ChainDestination)
	if err != nil {
		log.Fatalf("Failed to pack method call: %v", err)
	}

	// Convert the string to common.Address
	address := common.HexToAddress(contractAddress)

	// Estimate gas limit
	gasLimit, err := client.EstimateGas(context.Background(), ethereum.CallMsg{
		To:   &address,
		Data: callData, // Replace with actual call data
	})
	if err != nil {
		log.Fatalf("Failed to estimate gas limit: %v", err)
	}
	gasLimit += 100000
	auth.GasLimit = gasLimit

	// Suggest gas price
	gasPrice, err := client.SuggestGasPrice(context.Background())
	if err != nil {
		log.Fatalf("Failed to suggest gas price: %v", err)
	}
	auth.GasPrice = gasPrice

	// Get the next available nonce
	// fetchnonce, err := client.PendingNonceAt(context.Background(), auth.From)
	// if err != nil {
	// 	log.Printf("Failed to get nonce: %v", err)
	// }

	var nonce models.Nonce
	if err := db.Where("address = ?", contractAddress).First(&nonce).Error; err != nil {
		log.Printf("Failed to get nonce from DB: %v", err)
	} else {
		auth.Nonce = big.NewInt(int64(nonce.Nonce))
		nonce.Nonce += 2

		db.Where("address = ?", contractAddress).Save(&nonce)
	}

	// Transact with the contract
	_, err = instance.Transact(auth, "issueLogBridge", event.Sender, event.Receiver, event.OriginalContract, trxHash, event.NumTokens, event.Message, event.ChainDestination)
	if err != nil {
		log.Printf("Failed to issue log bridge: %v", err)
		return
	}

	transaction.Status = "LogIssued"
	db.Where("transaction_hash = ?", transaction.TransactionHash).Save(&transaction)

	// Suggest gas price
	gasPrice1, err := client.SuggestGasPrice(context.Background())
	if err != nil {
		log.Fatalf("Failed to suggest gas price1: %v", err)
	}
	auth.GasPrice = gasPrice1

	// Adjust gas limit and nonce for the next transaction
	auth.GasLimit = gasLimit + 20000 // Adjust if necessary
	// auth.Nonce = big.NewInt(int64(nonce + 1)) // Increment nonce
	// Increment nonce manually
	auth.Nonce.Add(auth.Nonce, big.NewInt(1))

	_, err = instance.Transact(auth, "acceptBridge", trxHash, event.Sender, event.Receiver)
	if err != nil {
		log.Printf("Failed to accept bridge: %v", err)
		return
	}

	transaction.Status = "Completed"
	db.Where("transaction_hash = ?", transaction.TransactionHash).Save(&transaction)
}
