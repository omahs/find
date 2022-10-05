import FungibleToken from "./standard/FungibleToken.cdc"
import DapperUtilityCoin from "./standard/DapperUtilityCoin.cdc"
import TokenForwarding from "./standard/TokenForwarding.cdc"

pub contract FindIOU {

	pub event IOUCreated(type: String, amount: UFix64)
	pub event IOUToppedUp(type: String, amount: UFix64, from: UFix64, to: UFix64)
	pub event IOURedeemed(type: String, amount: UFix64)

	pub resource interface IOU {
		pub let vaultType : Type 
		pub var amount : UFix64 
		pub fun topUp(_ vault: @FungibleToken.Vault)
	}

	pub resource EscrowedIOU {
		pub let vaultType : Type 
		pub var balance : UFix64 
		access(self) let vault : @FungibleToken.Vault

		init(_ vault: @FungibleToken.Vault) {
			self.vaultType = vault.getType()
			self.balance = vault.balance
			self.vault <- vault
		}

		destroy() {
			pre {
				self.vault.balance == 0.0 : "balance of vault in IOU cannot be non-zero when destroy"
			}
			destroy self.vault
		}

		pub fun createEmptyVault() : @FungibleToken.Vault {
			return <- self.vault.withdraw(amount: 0.0)
		}

		pub fun topUp(_ vault: @FungibleToken.Vault) {
			pre{
				self.vaultType == vault.getType() : "The vault type passed in does not match with the redeeming iou. Required vault type : ".concat(self.vaultType.identifier)
			}
			emit IOUToppedUp(type: self.vaultType.identifier, amount: vault.balance, from: self.balance, to: self.balance + vault.balance)

			if self.vaultType == Type<@DapperUtilityCoin.Vault>() {
				// Handle Dapper stuff here
				let receiver = FindIOU.account.borrow<&{FungibleToken.Receiver}>(from: /storage/dapperUtilityCoinReceiver)
					?? panic("Cannot borrow DUC receiver vault balance from FIND.")

				self.balance = self.balance + vault.balance
				receiver.deposit(from: <- vault) 
				
				return 
			}

			self.vault.deposit(from: <- vault)
			self.balance = self.vault.balance 
			return
		}

		access(contract) fun redeem() : @FungibleToken.Vault {
			return <- self.vault.withdraw(amount: self.vault.balance)
		}

	}

	pub fun createIOU(_ vault: @FungibleToken.Vault) : @EscrowedIOU {
		emit IOUCreated(type: vault.getType().identifier, amount: vault.balance)
		if vault.getType() == Type<@DapperUtilityCoin.Vault>() {
			// Handle Dapper stuff here
			let receiver = FindIOU.account.borrow<&{FungibleToken.Receiver}>(from: /storage/dapperUtilityCoinReceiver)
				?? panic("Cannot borrow DUC receiver vault balance from FIND.")

			let iou <- create EscrowedIOU(<- vault)
			receiver.deposit(from: <- iou.redeem()) 

			return <- iou
		}

		let iou <- create EscrowedIOU(<- vault)
		return <- iou
	}

	pub fun redeemIOU(iou: @EscrowedIOU, vault: @FungibleToken.Vault) : @FungibleToken.Vault {
		pre {
			iou.vaultType == vault.getType() : "The vault type passed in does not match with the redeeming iou. Required vault type : ".concat(iou.vaultType.identifier)
		}
		emit IOURedeemed(type: iou.vaultType.identifier, amount: iou.balance)

		if iou.vaultType == Type<@DapperUtilityCoin.Vault>() {
			if vault.balance != iou.balance {
				panic("The passed in vault amount for DUC does not match the amount in IOU. Required amount : ".concat(iou.balance.toString()))
			}
			destroy iou 
			return <- vault 
		}

		vault.deposit(from: <- iou.redeem())

		destroy iou 
		return <- vault
	}

}