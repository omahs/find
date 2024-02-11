import "FindMarketDirectOfferSoft"
import "NonFungibleToken"
import "MetadataViews"
import "FindViews"
import "FINDNFTCatalog"
import "FindMarket"

transaction(id: UInt64) {

	let market : auth(FindMarketDirectOfferSoft.Seller) &FindMarketDirectOfferSoft.SaleItemCollection
	let pointer : FindViews.AuthNFTPointer

	prepare(account: auth(BorrowValue) &Account) {
		let marketplace = FindMarket.getFindTenantAddress()
		let tenant=FindMarket.getTenant(marketplace)
		let storagePath=tenant.getStoragePath(Type<@FindMarketDirectOfferSoft.SaleItemCollection>())
		self.market = account.storage.borrow<auth(FindMarketDirectOfferSoft.Seller) &FindMarketDirectOfferSoft.SaleItemCollection>(from: storagePath)!
		let marketOption = FindMarket.getMarketOptionFromType(Type<@FindMarketDirectOfferSoft.SaleItemCollection>())
		let item = FindMarket.assertOperationValid(tenant: marketplace, address: account.address, marketOption: marketOption, id: id)
		let nftIdentifier = item.getItemType().identifier

		//If this is nil, there must be something wrong with FIND setup
		// let privatePath = getPrivatePath(nftIdentifier)

		let collectionIdentifier = FINDNFTCatalog.getCollectionsForType(nftTypeIdentifier: nftIdentifier)?.keys ?? panic("This NFT is not supported by the NFT Catalog yet. Type : ".concat(nftIdentifier))
		let collection = FINDNFTCatalog.getCatalogEntry(collectionIdentifier : collectionIdentifier[0])!
		let privatePath = collection.collectionData.privatePath


		let providerCap=account.getCapability<&{NonFungibleToken.Provider, ViewResolver.ResolverCollection, NonFungibleToken.Collection}>(privatePath)
		self.pointer= FindViews.AuthNFTPointer(cap: providerCap, id: item.getItemID())
	}

	execute {
		self.market.acceptOffer(self.pointer)
	}
}
