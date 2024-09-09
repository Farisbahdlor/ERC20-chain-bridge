package handlers

import (
	"bsc-mainnet/config"
	"bsc-mainnet/models"
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type BridgeRequest struct {
	OriginalContractAddress string `json:"original_contract_address"`
	NumTokens               uint64 `json:"num_tokens"`
	ChainDestination        uint64 `json:"chain_destination"`
	Message                 string `json:"message"`
	TransactionHash         string `json:"transaction_hash"`
}

func HandleBridgeRequest(db *gorm.DB, cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {

		transactionhash := c.Param("transactionhash")

		var request BridgeRequest
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		transaction := models.Transaction{}

		if err := db.Where("transactionhash = ?", transactionhash).First(&transaction).Error; err != nil {
			c.JSON(http.StatusOK, gin.H{"status": "Transaction bridge not initialize to verify"})
			return
		}

		c.JSON(http.StatusOK, transaction.Status)

		// // Logic to handle the bridge request
		// transaction := models.Transaction{
		// 	Sender:           c.ClientIP(), // ganti clientIP dengan wallet address user
		// 	OriginalContract: request.OriginalContractAddress,
		// 	NumTokens:        request.NumTokens,
		// 	ChainID:          request.ChainDestination,
		// 	TransactionHash:  request.TransactionHash,
		// 	Status:           "Pending",
		// 	Message:          request.Message,
		// }

		// db.Create(&transaction)

		// // Notify the blockchain listener about this request
		// go services.ProcessTransaction(nil, services.Event{
		// 	Sender:           common.HexToAddress(c.ClientIP()),
		// 	Receiver: common.,
		// 	OriginalContract: common.HexToAddress(request.OriginalContractAddress),
		// 	NumTokens:        big.NewInt(int64(request.NumTokens)),
		// 	Message:          request.Message,
		// 	ChainDestination: request.ChainDestination,
		// }, transaction, int(request.ChainDestination), db, cfg)

		// c.JSON(http.StatusOK, gin.H{"status": "Transaction processed"})
	}
}
