import FindMarket from "../contracts/FindMarket.cdc"
import FlowToken from "../contracts/standard/FlowToken.cdc"
import FUSD from "../contracts/standard/FUSD.cdc"
import NonFungibleToken from "../contracts/standard/NonFungibleToken.cdc"
import MetadataViews from "../contracts/standard/MetadataViews.cdc"
import Dandy from "../contracts/Dandy.cdc"
import FindViews from "../contracts/FindViews.cdc"

transaction(id: UInt64, price:UFix64) {
	prepare(account: AuthAccount) {
		let tenant=FindMarket.getFindTenant()
		let saleItems= account.borrow<&FindMarket.SaleItemCollection>(from: tenant.information.saleItemStoragePath) ?? panic("Cannot find saleItems")

		let dandyPrivateCap=	account.getCapability<&Dandy.Collection{NonFungibleToken.Provider, MetadataViews.ResolverCollection, NonFungibleToken.Receiver}>(Dandy.CollectionPrivatePath)

		let pointer= FindViews.AuthNFTPointer(cap: dandyPrivateCap, id: id)
		saleItems.listForAuction(pointer: pointer, vaultType: Type<@FUSD.Vault>(), auctionStartPrice: price, auctionReservePrice: price+5.0, auctionDuration: 300.0, auctionExtensionOnLateBid: 60.0, minimumBidIncrement: 1.0)

	}
}