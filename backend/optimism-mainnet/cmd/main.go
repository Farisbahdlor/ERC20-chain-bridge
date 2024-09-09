package main

import (
	"context"
	"log"
	"optimism-mainnet/config"
	"optimism-mainnet/handlers"
	"optimism-mainnet/models"
	"optimism-mainnet/services"

	"github.com/ethereum/go-ethereum/common"
	"github.com/gin-gonic/gin"
)

func main() {
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Error loading config: %v", err)
	}

	db, err := models.ConnectDatabase(cfg.PostgresDSN)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	router := gin.Default()
	router.GET("/bridgestatus/:transactionhash", handlers.HandleBridgeRequest(db, cfg))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go services.ListenChain(ctx, cfg.OptimismRPC, common.HexToAddress(cfg.ContractAddressOptimism), db, cfg.OptimismChainID, cfg)

	router.Run(":3001")
}
