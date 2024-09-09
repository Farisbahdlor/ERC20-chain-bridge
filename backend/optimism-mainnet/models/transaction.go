package models

import "gorm.io/gorm"

type Transaction struct {
	gorm.Model
	Sender           string
	Receiver         string
	OriginalContract string
	NumTokens        string
	ChainID          string
	TransactionHash  string
	Status           string
	Message          string
}

type Nonce struct {
	gorm.Model
	Address string
	Nonce   uint64
}
