import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import FTRegistry from "../contracts/FTRegistry.cdc"
import FindIOU from "../contracts/FindIOU.cdc"


transaction(id: UInt64, amount: UFix64) {
	
	prepare(account: AuthAccount) {

		let collectionRef = account.borrow<&FindIOU.Collection>(from: FindIOU.CollectionStoragePath)!
		let vaultType = collectionRef.borrowIOU(id).vaultType.identifier

		let ft = FTRegistry.getFTInfo(vaultType) ?? panic("This FT is not supported by the Find Market yet. Type : ".concat(vaultType))
		let walletReference = account.borrow<&FungibleToken.Vault>(from: ft.vaultPath)!
		let vault <- walletReference.withdraw(amount: amount)

		collectionRef.topUp(id: id, vault: <- vault)
	}
}

