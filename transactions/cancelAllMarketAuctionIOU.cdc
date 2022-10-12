import FindMarket from "../contracts/FindMarket.cdc"
import FindMarketAuctionIOUEscrowed from "../contracts/FindMarketAuctionIOUEscrowed.cdc"

transaction(marketplace:Address) {

	let saleItems : &FindMarketAuctionIOUEscrowed.SaleItemCollection?

	prepare(account: AuthAccount) {
		let tenant = FindMarket.getTenant(marketplace)
		self.saleItems= account.borrow<&FindMarketAuctionIOUEscrowed.SaleItemCollection>(from: tenant.getStoragePath(Type<@FindMarketAuctionIOUEscrowed.SaleItemCollection>()))

	}

	pre{
		self.saleItems != nil : "Cannot borrow reference to the saleItem capability."
	}

	execute {
		let ids = self.saleItems!.getIds()
		for id in ids {
			self.saleItems!.cancel(id)
		}
	}
}
