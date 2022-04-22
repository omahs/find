import FindMarket from "../contracts/FindMarket.cdc"
import FindMarketDirectOfferSoft from "../contracts/FindMarketDirectOfferSoft.cdc"
import FUSD from "../contracts/standard/FUSD.cdc"

//TODO: this needs work for DUC
//TODO: this will not work for DUC, we need totally seperate TX for them or we need to just not check bid balance.
transaction(id: UInt64, amount: UFix64) {

	let bidsReference: &FindMarketDirectOfferSoft.MarketBidCollection

	prepare(account: AuthAccount) {
		let tenant=FindMarket.getFindTenantCapability().borrow() ?? panic("Cannot borrow reference to tenant")
		let storagePath=tenant.getStoragePath(Type<@FindMarketDirectOfferSoft.MarketBidCollection>())!
		self.bidsReference= account.borrow<&FindMarketDirectOfferSoft.MarketBidCollection>(from: storagePath) ?? panic("Bid resource does not exist")
	}

	execute {
		self.bidsReference.increaseBid(id: id, increaseBy: amount)
	}
}

