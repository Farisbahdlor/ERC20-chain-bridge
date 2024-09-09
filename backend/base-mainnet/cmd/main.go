package main

import (
	"base-mainnet/config"
	"base-mainnet/handlers"
	"base-mainnet/models"
	"base-mainnet/services"
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

	go services.ListenChain(ctx, cfg.BaseMainnetRPC, common.HexToAddress(cfg.ContractAddressBase), db, cfg.BaseChainID, cfg)

	router.Run(":3001")
}
