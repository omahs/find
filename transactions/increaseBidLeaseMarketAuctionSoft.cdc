import "FindLeaseMarketAuctionSoft"
import "FungibleToken"
import "FTRegistry"
import "FindMarket"
import "FindLeaseMarket"

transaction(leaseName: String, amount: UFix64) {

	let bidsReference: auth(FindLeaseMarketAuctionSoft.Buyer) &FindLeaseMarketAuctionSoft.MarketBidCollection

	prepare(account: auth(BorrowValue) &Account) {
		let marketplace = FindMarket.getFindTenantAddress()
		let tenant=FindMarket.getTenant(marketplace)
		let storagePath=tenant.getStoragePath(Type<@FindLeaseMarketAuctionSoft.MarketBidCollection>())
		self.bidsReference= account.storage.borrow<auth(FindLeaseMarketAuctionSoft.Buyer) &FindLeaseMarketAuctionSoft.MarketBidCollection>(from: storagePath) ?? panic("Bid resource does not exist")
		// get Bidding Fungible Token Vault
	  	let marketOption = FindMarket.getMarketOptionFromType(Type<@FindLeaseMarketAuctionSoft.MarketBidCollection>())
		let item = FindLeaseMarket.assertBidOperationValid(tenant: marketplace, address: account.address, marketOption: marketOption, name: leaseName)

		let ft = FTRegistry.getFTInfoByTypeIdentifier(item.getFtType().identifier) ?? panic("This FT is not supported by the Find Market yet. Type : ".concat(item.getFtType().identifier))

	}

	execute {
		self.bidsReference.increaseBid(name: leaseName, increaseBy: amount)
	}

}

