import FungibleToken from "./standard/FungibleToken.cdc"
import FlowToken from "./standard/FlowToken.cdc"
import NonFungibleToken from "./standard/NonFungibleToken.cdc"
import MetadataViews from "./standard/MetadataViews.cdc"
import FindViews from "../contracts/FindViews.cdc"
import Clock from "./Clock.cdc"
import Debug from "./Debug.cdc"
import FIND from "./FIND.cdc"
import FindMarket from "./FindMarket.cdc"
import FindLeaseMarket from "./FindLeaseMarket.cdc"

access(all) contract FindLeaseMarketDirectOfferSoft {

	access(all) event DirectOffer(tenant: String, id: UInt64, saleID: UInt64, seller: Address, sellerName: String?, amount: UFix64, status: String, vaultType:String, leaseInfo: FindLeaseMarket.LeaseInfo?, buyer:Address?, buyerName:String?, buyerAvatar:String?, endsAt: UFix64?, previousBuyer:Address?, previousBuyerName:String?)

	access(all) resource SaleItem : FindLeaseMarket.SaleItem {

		access(contract) var pointer: AnyStruct{FindLeaseMarket.LeasePointer}
		access(contract) var offerCallback: Capability<&MarketBidCollection{MarketBidCollectionPublic}>

		access(contract) var directOfferAccepted:Bool
		access(contract) var validUntil: UFix64?
		access(contract) var saleItemExtraField: {String : AnyStruct}

		init(pointer: FindLeaseMarket.ReadLeasePointer, callback: Capability<&MarketBidCollection{MarketBidCollectionPublic}>, validUntil: UFix64?, saleItemExtraField: {String : AnyStruct}) {
			self.offerCallback=callback
			self.directOfferAccepted=false
			self.validUntil=validUntil
			self.saleItemExtraField=saleItemExtraField
			self.pointer=pointer
		}

		access(all) getName() : String {
			return self.pointer.name
		}

		access(all) acceptDirectOffer() {
			self.directOfferAccepted=true
		}

		//Here we do not get a vault back, it is sent in to the method itself
		access(all) acceptNonEscrowedBid() {
			pre{
				self.offerCallback.check() : "Bidder unlinked the bid collection capability."
				self.pointer != nil : "Please accept offer"
			}
			self.offerCallback.borrow()!.acceptNonEscrowed(self.getLeaseName())
			let pointer = self.pointer as! FindLeaseMarket.AuthLeasePointer
			pointer.move(to: self.offerCallback.address)
		}

		access(all) getFtType() : Type {
			pre{
				self.offerCallback.check() : "Bidder unlinked the bid collection capability."
			}
			return self.offerCallback.borrow()!.getVaultType(self.getLeaseName())
		}

		access(all) getLeaseName() : String {
			return self.pointer.name
		}

		access(all) getItemType() : Type {
			return Type<@FIND.Lease>()
		}

		access(all) getAuction(): FindLeaseMarket.AuctionItem? {
			return nil
		}

		access(all) getId() : UInt64 {
			return self.pointer.getUUID()
		}

		access(all) getSaleType() : String {
			if self.directOfferAccepted {
				return "active_finished"
			}
			return "active_ongoing"
		}

		access(all) getListingType() : Type {
			return Type<@SaleItem>()
		}

		access(all) getListingTypeIdentifier() : String {
			return Type<@SaleItem>().identifier
		}

		access(all) getBalance() : UFix64 {
			pre{
				self.offerCallback.check() : "Bidder unlinked the bid collection capability."
			}
			return self.offerCallback.borrow()!.getBalance(self.getLeaseName())
		}

		access(all) getSeller() : Address {
			return self.pointer.owner()
		}

		access(all) getSellerName() : String? {
			let address = self.pointer.owner()
			return FIND.reverseLookup(address)
		}

		access(all) getBuyer() : Address? {
			return self.offerCallback.address
		}

		access(all) getBuyerName() : String? {
			if let name = FIND.reverseLookup(self.offerCallback.address) {
				return name
			}
			return nil
		}

		access(all) toLeaseInfo() : FindLeaseMarket.LeaseInfo{
			return FindLeaseMarket.LeaseInfo(self.pointer)
		}

		access(all) setValidUntil(_ time: UFix64?) {
			self.validUntil=time
		}

		access(all) getValidUntil() : UFix64? {
			return self.validUntil
		}

		access(all) setPointer(_ pointer: FindLeaseMarket.AuthLeasePointer) {
			self.pointer=pointer
		}

		access(all) setCallback(_ callback: Capability<&MarketBidCollection{MarketBidCollectionPublic}>) {
			self.offerCallback=callback
		}

		access(all) checkPointer() : Bool {
			return self.pointer.valid()
		}

		access(all) getSaleItemExtraField() : {String : AnyStruct} {
			return self.saleItemExtraField
		}

		access(contract) fun setSaleItemExtraField(_ field: {String : AnyStruct}) {
			self.saleItemExtraField = field
		}

	}

	access(all) resource interface SaleItemCollectionPublic {
		//fetch all the tokens in the collection
		access(all) getNameSales(): [String]
		access(all) containsNameSale(_ name: String): Bool
		access(contract) fun cancelBid(_ name: String)
		access(contract) fun registerIncreasedBid(_ name: String)

		//place a bid on a token
		access(contract) fun registerBid(name: String, callback: Capability<&MarketBidCollection{MarketBidCollectionPublic}>, validUntil: UFix64?, saleItemExtraField: {String : AnyStruct})

		access(contract) fun isAcceptedDirectOffer(_ name:String) : Bool

		access(contract) fun fulfillDirectOfferNonEscrowed(name:String, vault: @FungibleToken.Vault)

		}

	access(all) resource SaleItemCollection: SaleItemCollectionPublic, FindLeaseMarket.SaleItemCollectionPublic {
		//is this the best approach now or just put the NFT inside the saleItem?
		access(contract) var items: @{String: SaleItem}

		access(contract) let tenantCapability: Capability<&FindMarket.Tenant{FindMarket.TenantPublic}>

		init (_ tenantCapability: Capability<&FindMarket.Tenant{FindMarket.TenantPublic}>) {
			self.items <- {}
			self.tenantCapability=tenantCapability
		}

		access(self) fun getTenant() : &FindMarket.Tenant{FindMarket.TenantPublic} {
			pre{
				self.tenantCapability.check() : "Tenant client is not linked anymore"
			}
			return self.tenantCapability.borrow()!
		}

		access(all) isAcceptedDirectOffer(_ name:String) : Bool{
			pre {
				self.items.containsKey(name) : "Invalid name sale=".concat(name)
			}
			let saleItem = self.borrow(name)

			return saleItem.directOfferAccepted
		}

		access(all) getListingType() : Type {
			return Type<@SaleItem>()
		}

		//this is called when a buyer cancel a direct offer
		access(contract) fun cancelBid(_ name: String) {
			pre {
				self.items.containsKey(name) : "Invalid name sale=".concat(name)
			}
			let saleItem=self.borrow(name)

			let actionResult=self.getTenant().allowedAction(listingType: self.getListingType(), nftType: saleItem.getItemType(), ftType: saleItem.getFtType(), action: FindMarket.MarketAction(listing:false, name:"cancel bid in direct offer soft"), seller: nil, buyer: nil)

			if !actionResult.allowed {
				panic(actionResult.message)
			}

			self.emitEvent(saleItem: saleItem, status: "cancel", previousBuyer: nil)
			destroy <- self.items.remove(key: name)
		}


		access(self) fun emitEvent(saleItem: &SaleItem, status: String, previousBuyer:Address?) {
			let owner=saleItem.getSeller()
			let ftType=saleItem.getFtType()
			let balance=saleItem.getBalance()
			let buyer=saleItem.getBuyer()!
			let buyerName=FIND.reverseLookup(buyer)
			let profile = FIND.lookup(buyer.toString())

			var leaseInfo:FindLeaseMarket.LeaseInfo?=nil
			if saleItem.checkPointer() {
				leaseInfo=saleItem.toLeaseInfo()
			}

			var previousBuyerName : String?=nil
			if let pb= previousBuyer {
				previousBuyerName = FIND.reverseLookup(pb)
			}

			emit DirectOffer(tenant:self.getTenant().name, id: saleItem.getId(), saleID: saleItem.uuid, seller:owner, sellerName: FIND.reverseLookup(owner), amount: balance, status:status, vaultType: ftType.identifier, leaseInfo:leaseInfo, buyer: buyer, buyerName: buyerName, buyerAvatar: profile?.getAvatar(), endsAt: saleItem.validUntil, previousBuyer:previousBuyer, previousBuyerName:previousBuyerName)
		}


		//The only thing we do here is basically register an event
		access(contract) fun registerIncreasedBid(_ name: String) {
			pre {
				self.items.containsKey(name) : "Invalid name sale=".concat(name)
			}
			let saleItem=self.borrow(name)

			let actionResult=self.getTenant().allowedAction(listingType: self.getListingType(), nftType: saleItem.getItemType(), ftType: saleItem.getFtType(), action: FindMarket.MarketAction(listing:true, name:"increase bid in direct offer soft"), seller: self.owner!.address, buyer: saleItem.offerCallback.address)

			if !actionResult.allowed {
				panic(actionResult.message)
			}

			self.emitEvent(saleItem: saleItem, status: "active_offered", previousBuyer:nil)
		}


		//This is a function that buyer will call (via his bid collection) to register the bicCallback with the seller
		access(contract) fun registerBid(name: String, callback: Capability<&MarketBidCollection{MarketBidCollectionPublic}>, validUntil: UFix64?, saleItemExtraField: {String : AnyStruct}) {

			//If there are no bids from anybody else before we need to make the item
			if !self.items.containsKey(name) {
				let item = FindLeaseMarket.ReadLeasePointer(name: name)
				let saleItem <- create SaleItem(pointer: item, callback: callback, validUntil: validUntil, saleItemExtraField: saleItemExtraField)
				let actionResult=self.getTenant().allowedAction(listingType: self.getListingType(), nftType: saleItem.getItemType(), ftType: saleItem.getFtType(), action: FindMarket.MarketAction(listing:true, name:"bid in direct offer soft"), seller: self.owner!.address, buyer: callback.address)

				if !actionResult.allowed {
					panic(actionResult.message)
				}
				self.items[name] <-! saleItem
				let saleItemRef=self.borrow(name)
				self.emitEvent(saleItem: saleItemRef, status: "active_offered", previousBuyer:nil)
				return
			}


			let saleItem=self.borrow(name)
			if self.borrow(name).getBuyer()! == callback.address {
				panic("You already have the latest bid on this item, use the incraseBid transaction")
			}

			let actionResult=self.getTenant().allowedAction(listingType: self.getListingType(), nftType: saleItem.getItemType(), ftType: saleItem.getFtType(), action: FindMarket.MarketAction(listing:true, name:"bid in direct offer soft"), seller: self.owner!.address, buyer: callback.address)

			if !actionResult.allowed {
				panic(actionResult.message)
			}

			let balance=callback.borrow()?.getBalance(name) ?? panic("Bidder unlinked the bid collection capability. bidder address : ".concat(callback.address.toString()))

			let currentBalance=saleItem.getBalance()
			Debug.log("currentBalance=".concat(currentBalance.toString()).concat(" new bid is at=").concat(balance.toString()))
			if currentBalance >= balance {
				panic("There is already a higher bid on this item. Current bid : ".concat(currentBalance.toString()).concat(" . New bid is at : ").concat(balance.toString()))
			}
			let previousBuyer=saleItem.offerCallback.address
			//somebody else has the highest item so we cancel it
			saleItem.offerCallback.borrow()!.cancelBidFromSaleItem(name)
			saleItem.setValidUntil(validUntil)
			saleItem.setSaleItemExtraField(saleItemExtraField)
			saleItem.setCallback(callback)

			self.emitEvent(saleItem: saleItem, status: "active_offered", previousBuyer:previousBuyer)

		}


		//cancel will reject a direct offer
		access(all) cancel(_ name: String) {
			pre {
				self.items.containsKey(name) : "Invalid name sale=".concat(name)
			}

			let saleItem=self.borrow(name)

			let actionResult=self.getTenant().allowedAction(listingType: self.getListingType(), nftType: saleItem.getItemType(), ftType: saleItem.getFtType(), action: FindMarket.MarketAction(listing:false, name:"reject offer in direct offer soft"), seller: nil, buyer: nil)

			if !actionResult.allowed {
				panic(actionResult.message)
			}

			self.emitEvent(saleItem: saleItem, status: "cancel_rejected", previousBuyer:nil)
			if !saleItem.offerCallback.check() {
				panic("Seller unlinked the SaleItem collection capability. seller address : ".concat(saleItem.offerCallback.address.toString()))
			}
			saleItem.offerCallback.borrow()!.cancelBidFromSaleItem(name)
			destroy <- self.items.remove(key: name)
		}

		access(all) acceptOffer(_ pointer: FindLeaseMarket.AuthLeasePointer) {
			pre {
				self.items.containsKey(pointer.name) : "Invalid name sale=".concat(pointer.name)
			}

			let saleItem = self.borrow(pointer.name)

			if saleItem.validUntil != nil && saleItem.validUntil! < Clock.time() {
				panic("This direct offer is already expired")
			}

			let actionResult=self.getTenant().allowedAction(listingType: self.getListingType(), nftType: saleItem.getItemType(), ftType: saleItem.getFtType(), action: FindMarket.MarketAction(listing:false, name:"accept offer in direct offer soft"), seller: self.owner!.address, buyer: saleItem.offerCallback.address)

			if !actionResult.allowed {
				panic(actionResult.message)
			}

			//Set the auth pointer in the saleItem so that it now can be fulfilled
			saleItem.setPointer(pointer)
			saleItem.acceptDirectOffer()

			self.emitEvent(saleItem: saleItem, status: "active_accepted", previousBuyer:nil)
		}

		/// this is called from a bid when a seller accepts
		access(contract) fun fulfillDirectOfferNonEscrowed(name:String, vault: @FungibleToken.Vault) {
			pre {
				self.items.containsKey(name) : "Invalid name sale=".concat(name)
			}

			let saleItem = self.borrow(name)
			if !saleItem.directOfferAccepted {
				panic("cannot fulfill a direct offer that is not accepted yet")
			}

			if vault.getType() != saleItem.getFtType() {
				panic("The FT vault sent in to fulfill does not match the required type. Required Type : ".concat(saleItem.getFtType().identifier).concat(" . Sent-in vault type : ".concat(vault.getType().identifier)))
			}
			let actionResult=self.getTenant().allowedAction(listingType: self.getListingType(), nftType: saleItem.getItemType(), ftType: saleItem.getFtType(), action: FindMarket.MarketAction(listing:false, name:"fulfill directOffer"), seller: self.owner!.address, buyer: saleItem.offerCallback.address)

			if !actionResult.allowed {
				panic(actionResult.message)
			}

			let cuts= self.getTenant().getCuts(name: actionResult.name, listingType: self.getListingType(), nftType: saleItem.getItemType(), ftType: saleItem.getFtType())

			self.emitEvent(saleItem: saleItem, status: "sold", previousBuyer:nil)
			let leaseInfo=saleItem.toLeaseInfo()
			saleItem.acceptNonEscrowedBid()
			FindLeaseMarket.pay(tenant: self.getTenant().name, leaseName:name, saleItem: saleItem, vault: <- vault, leaseInfo: leaseInfo, cuts:cuts)

			destroy <- self.items.remove(key: name)
		}

		access(all) getNameSales(): [String] {
			return self.items.keys
		}

		access(all) containsNameSale(_ name: String): Bool {
			return self.items.containsKey(name)
		}

		access(all) borrow(_ name: String): &SaleItem {
			pre{
				self.items.containsKey(name) : "This name sale does not exist.".concat(name)
			}
			return (&self.items[name] as &SaleItem?)!
		}

		access(all) borrowSaleItem(_ name: String) : &{FindLeaseMarket.SaleItem} {
			pre{
				self.items.containsKey(name) : "This name sale does not exist.".concat(name)
			}
			return (&self.items[name] as &SaleItem{FindLeaseMarket.SaleItem}?)!
		}

		destroy() {
			destroy self.items
		}
	}

	/*
	==========================================================================
	Bids are a collection/resource for storing the bids bidder made on leases
	==========================================================================
	*/

	access(all) resource Bid : FindLeaseMarket.Bid {
		access(contract) let from: Capability<&SaleItemCollection{SaleItemCollectionPublic}>
		access(contract) let leaseName: String

		//this should reflect on what the above uuid is for
		access(contract) let vaultType: Type
		access(contract) var bidAt: UFix64
		access(contract) var balance: UFix64 //This is what you bid for non escrowed bids
		access(contract) let bidExtraField: {String : AnyStruct}

		init(from: Capability<&SaleItemCollection{SaleItemCollectionPublic}>, leaseName: String, vaultType:Type,  nonEscrowedBalance:UFix64, bidExtraField: {String : AnyStruct}){
			self.vaultType= vaultType
			self.balance=nonEscrowedBalance
			self.leaseName=leaseName
			self.from=from
			self.bidAt=Clock.time()
			self.bidExtraField=bidExtraField
		}

		access(contract) fun setBidAt(_ time: UFix64) {
			self.bidAt=time
		}

		access(contract) fun increaseBid(_ amount:UFix64) {
			self.balance=self.balance+amount
		}

		access(all) getBalance() : UFix64 {
			return self.balance
		}

		access(all) getSellerAddress() : Address {
			return self.from.address
		}

		access(all) getBidExtraField() : {String : AnyStruct} {
			return self.bidExtraField
		}
	}

	access(all) resource interface MarketBidCollectionPublic {
		access(all) getBalance(_ name: String) : UFix64
		access(all) getVaultType(_ name: String) : Type
		access(all) containsNameBid(_ name: String): Bool
		access(all) getNameBids() : [String]
		access(contract) fun acceptNonEscrowed(_ name: String)
		access(contract) fun cancelBidFromSaleItem(_ name: String)
	}

	//A collection stored for bidders/buyers
	access(all) resource MarketBidCollection: MarketBidCollectionPublic, FindLeaseMarket.MarketBidCollectionPublic {

		access(contract) var bids : @{String: Bid}
		access(contract) let receiver: Capability<&{FungibleToken.Receiver}>
		access(contract) let tenantCapability: Capability<&FindMarket.Tenant{FindMarket.TenantPublic}>

		//not sure we can store this here anymore. think it needs to be in every bid
		init(receiver: Capability<&{FungibleToken.Receiver}>, tenantCapability: Capability<&FindMarket.Tenant{FindMarket.TenantPublic}>) {
			self.bids <- {}
			self.receiver=receiver
			self.tenantCapability=tenantCapability
		}

		access(self) fun getTenant() : &FindMarket.Tenant{FindMarket.TenantPublic} {
			pre{
				self.tenantCapability.check() : "Tenant client is not linked anymore"
			}
			return self.tenantCapability.borrow()!
		}

		//called from lease when auction is ended
		access(contract) fun acceptNonEscrowed(_ name: String) {
			let bid <- self.bids.remove(key: name) ?? panic("missing bid")
			destroy bid
		}

		access(all) getVaultType(_ name:String) : Type {
			return self.borrowBid(name).vaultType
		}

		access(all) getNameBids() : [String] {
			return self.bids.keys
		}

		access(all) containsNameBid(_ name: String) : Bool {
			return self.bids.containsKey(name)
		}

		access(all) getBidType() : Type {
			return Type<@Bid>()
		}


		access(all) bid(name: String, amount:UFix64, vaultType:Type, validUntil: UFix64?, saleItemExtraField: {String : AnyStruct}, bidExtraField: {String : AnyStruct}) {
			pre {
				self.owner!.address != FIND.status(name).owner!  : "You cannot bid on your own resource"
				self.bids[name] == nil : "You already have an bid for this item, use increaseBid on that bid"
			}

			// ensure it is not a 0 dollar listing
			if amount <= 0.0 {
				panic("Offer price should be greater than 0")
			}

			// ensure validUntil is valid
			if validUntil != nil && validUntil! < Clock.time() {
				panic("Valid until is before current time")
			}

			let from=getAccount(FIND.status(name).owner!).getCapability<&SaleItemCollection{SaleItemCollectionPublic}>(self.getTenant().getPublicPath(Type<@SaleItemCollection>()))

			let bid <- create Bid(from: from, leaseName: name, vaultType: vaultType, nonEscrowedBalance:amount, bidExtraField: bidExtraField)
			let saleItemCollection= from.borrow() ?? panic("Could not borrow sale item for name=".concat(name))
			let callbackCapability =self.owner!.getCapability<&MarketBidCollection{MarketBidCollectionPublic}>(self.getTenant().getPublicPath(Type<@MarketBidCollection>()))

			let oldToken <- self.bids[name] <- bid
			saleItemCollection.registerBid(name: name, callback: callbackCapability, validUntil: validUntil, saleItemExtraField: saleItemExtraField)
			destroy oldToken
		}

		access(all) fulfillDirectOffer(name:String, vault: @FungibleToken.Vault) {
			pre {
				self.bids[name] != nil : "You need to have a bid here already"
			}

			let bid =self.borrowBid(name)
			let saleItem=bid.from.borrow()!

			if !saleItem.isAcceptedDirectOffer(name) {
				panic("offer is not accepted yet")
			}

			saleItem.fulfillDirectOfferNonEscrowed(name:name, vault: <- vault)
		}

		access(all) increaseBid(name: String, increaseBy: UFix64) {
			let bid =self.borrowBid(name)
			bid.setBidAt(Clock.time())
			bid.increaseBid(increaseBy)
			if !bid.from.check() {
				panic("Seller unlinked the SaleItem collection capability. seller address : ".concat(bid.from.address.toString()))
			}
			bid.from.borrow()!.registerIncreasedBid(name)
		}

		/// The users cancel a bid himself
		access(all) cancelBid(_ name: String) {
			let bid= self.borrowBid(name)
			if !bid.from.check() {
				panic("Seller unlinked the SaleItem collection capability. seller address : ".concat(bid.from.address.toString()))
			}
			bid.from.borrow()!.cancelBid(name)
			self.cancelBidFromSaleItem(name)
		}

		//called from saleItem when things are cancelled
		//if the bid is canceled from seller then we move the vault tokens back into your vault
		access(contract) fun cancelBidFromSaleItem(_ name: String) {
			let bid <- self.bids.remove(key: name) ?? panic("missing bid")
			destroy bid
		}

		access(all) borrowBid(_ name: String): &Bid {
			pre{
				self.bids.containsKey(name) : "This name bid does not exist.".concat(name)
			}
			return (&self.bids[name] as &Bid?)!
		}

		access(all) borrowBidItem(_ name: String): &{FindLeaseMarket.Bid} {
			pre{
				self.bids.containsKey(name) : "This name bid does not exist.".concat(name)
			}
			return (&self.bids[name] as &Bid{FindLeaseMarket.Bid}?)!
		}

		access(all) getBalance(_ name: String) : UFix64 {
			let bid= self.borrowBid(name)
			return bid.balance
		}

		destroy() {
			destroy self.bids
		}
	}

	//Create an empty lease collection that store your leases to a name
	access(all) createEmptySaleItemCollection(_ tenantCapability: Capability<&FindMarket.Tenant{FindMarket.TenantPublic}>): @SaleItemCollection {
		return <- create SaleItemCollection(tenantCapability)
	}

	access(all) createEmptyMarketBidCollection(receiver: Capability<&{FungibleToken.Receiver}>, tenantCapability: Capability<&FindMarket.Tenant{FindMarket.TenantPublic}>) : @MarketBidCollection {
		return <- create MarketBidCollection(receiver: receiver, tenantCapability:tenantCapability)
	}

	access(all) getSaleItemCapability(marketplace:Address, user:Address) : Capability<&SaleItemCollection{SaleItemCollectionPublic, FindLeaseMarket.SaleItemCollectionPublic}>? {
		pre{
			FindMarket.getTenantCapability(marketplace) != nil : "Invalid tenant"
		}
		if let tenant=FindMarket.getTenantCapability(marketplace)!.borrow() {
			return getAccount(user).getCapability<&SaleItemCollection{SaleItemCollectionPublic, FindLeaseMarket.SaleItemCollectionPublic}>(tenant.getPublicPath(Type<@SaleItemCollection>()))
		}
		return nil
	}

	access(all) getBidCapability( marketplace:Address, user:Address) : Capability<&MarketBidCollection{MarketBidCollectionPublic, FindLeaseMarket.MarketBidCollectionPublic}>? {
		pre{
			FindMarket.getTenantCapability(marketplace) != nil : "Invalid tenant"
		}
		if let tenant=FindMarket.getTenantCapability(marketplace)!.borrow() {
			return getAccount(user).getCapability<&MarketBidCollection{MarketBidCollectionPublic, FindLeaseMarket.MarketBidCollectionPublic}>(tenant.getPublicPath(Type<@MarketBidCollection>()))
		}
		return nil
	}

	init() {
		FindLeaseMarket.addSaleItemType(Type<@SaleItem>())
		FindLeaseMarket.addSaleItemCollectionType(Type<@SaleItemCollection>())
		FindLeaseMarket.addMarketBidType(Type<@Bid>())
		FindLeaseMarket.addMarketBidCollectionType(Type<@MarketBidCollection>())
	}
}
