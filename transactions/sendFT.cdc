import FUSD from "../contracts/standard/FUSD.cdc"
import NonFungibleToken from "../contracts/standard/NonFungibleToken.cdc"
import FlowToken from "../contracts/standard/FlowToken.cdc"
import FIND from "../contracts/FIND.cdc"
import CharityNFT from "../contracts/CharityNFT.cdc"

transaction(name: String, amount: UFix64, type: String) {

	prepare(account: AuthAccount) {

		let charityCap = account.getCapability<&{NonFungibleToken.CollectionPublic}>(CharityNFT.CollectionPublicPath)

		if !charityCap.check() {
			account.save<@NonFungibleToken.Collection>(<- CharityNFT.createEmptyCollection(), to: CharityNFT.CollectionStoragePath)
			account.link<&{NonFungibleToken.CollectionPublic}>(CharityNFT.CollectionPublicPath, target: CharityNFT.CollectionStoragePath)
		}

		if type == "fusd" {
			let vaultRef = account.borrow<&FUSD.Vault>(from: /storage/fusdVault) ?? panic("Could not borrow reference to the fusdVault!")
			FIND.deposit(to: name, from: <- vaultRef.withdraw(amount: amount))
			return 
		}

		let vaultRef = account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) ?? panic("Could not borrow reference to the fusdVault!")
		FIND.deposit(to: name, from: <- vaultRef.withdraw(amount: amount))

	}

}

