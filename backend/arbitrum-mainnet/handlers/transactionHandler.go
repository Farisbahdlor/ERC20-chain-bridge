package handlers

import (
	"arbitrum-mainnet/models"
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func GetTransactionByHash(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		transactionHash := c.Param("transactionHash")

		var transaction models.Transaction
		if err := db.Where("transaction_hash = ?", transactionHash).First(&transaction).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Transaction not found"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"transaction": transaction})
	}
}

func GetAllTransactions(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var transactions []models.Transaction
		if err := db.Find(&transactions).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve transactions"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"transactions": transactions})
	}
}
