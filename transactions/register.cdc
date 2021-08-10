import FungibleToken from "../contracts/standard/FungibleToken.cdc"
import FUSD from "../contracts/standard/FUSD.cdc"
import Profile from "../contracts/Profile.cdc"
import FIN from "../contracts/FIN.cdc"


transaction(tag: String) {
	prepare(acct: AuthAccount) {

		let profileCap = acct.getCapability<&{Profile.Public}>(Profile.publicPath)

		let price=FIN.calculateCost(tag)
		log("The cost for registering this tag is ".concat(price.toString()))

		let vaultRef = acct.borrow<&FUSD.Vault>(from: /storage/fusdVault) ?? panic("Could not borrow reference to the owner's Vault!")
		let payVault <- vaultRef.withdraw(amount: price) as! @FUSD.Vault

		let finToken <- FIN.register(tag: tag, vault: <- payVault, profile: profileCap)

		let finLeases <- FIN.createEmptyCollection()
		finLeases.deposit(token: <- finToken)
		acct.save(<- finLeases, to: FIN.LeaseStoragePath)
		acct.link<&{FIN.LeaseCollectionPublic}>( FIN.LeasePublicPath, target: FIN.LeaseStoragePath)

		log("STATUS POST")
		log(FIN.status(tag))

	}
}
