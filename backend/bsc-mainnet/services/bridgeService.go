package services

import (
	"bsc-mainnet/models"

	"gorm.io/gorm"
)

func SaveTransaction(db *gorm.DB, transaction *models.Transaction) error {
	return db.Create(transaction).Error
}

func UpdateTransactionStatus(db *gorm.DB, transactionHash string, status string) error {
	return db.Model(&models.Transaction{}).Where("transaction_hash = ?", transactionHash).Update("status", status).Error
}
