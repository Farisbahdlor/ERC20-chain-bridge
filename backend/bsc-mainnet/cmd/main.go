package main

import (
	"bsc-mainnet/config"
	"bsc-mainnet/handlers"
	"bsc-mainnet/models"
	"bsc-mainnet/services"
	"context"
	"log"

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

	go services.ListenChain(ctx, cfg.BSCMainnetRPC, common.HexToAddress(cfg.ContractAddressBSC), db, cfg.BSCChainID, cfg)

	router.Run(":3001")
}
