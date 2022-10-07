package test_main

import (
	"testing"

	"github.com/bjartek/overflow"
	. "github.com/bjartek/overflow"
	"github.com/stretchr/testify/assert"
)

func TestMarketAuctionIOU(t *testing.T) {

	otu := NewOverflowTest(t)

	mintFund := otu.O.TxFN(
		WithSigner("account"),
		WithArg("amount", 10000.0),
		WithArg("recipient", "user2"),
	)

	price := 10.0
	preIncrement := 5.0
	id := otu.setupMarketAndDandy()
	otu.registerFtInRegistry().
		setFlowDandyMarketOption("Auction").
		setProfile("user1").
		setProfile("user2")

	mintFund("testMintFusd").AssertSuccess(t)

	mintFund("testMintFlow").AssertSuccess(t)

	mintFund("testMintUsdc").AssertSuccess(t)

	otu.setUUID(400)

	listingTx := otu.O.TxFN(
		WithSigner("user1"),
		WithArg("marketplace", "account"),
		WithArg("nftAliasOrIdentifier", "A.f8d6e0586b0a20c7.Dandy.NFT"),
		WithArg("id", id),
		WithArg("ftAliasOrIdentifier", "Flow"),
		WithArg("price", price),
		WithArg("auctionReservePrice", price),
		WithArg("auctionDuration", 300.0),
		WithArg("auctionExtensionOnLateBid", 60.0),
		WithArg("minimumBidIncrement", 1.0),
		WithArg("auctionValidUntil", otu.currentTime()+10.0),
	)

	t.Run("Should not be able to list an item for auction twice, and will give error message.", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price)

		listingTx("listNFTForAuctionIOU",
			WithSigner("user1"),
			WithArg("id", id),
			WithArg("auctionValidUntil", otu.currentTime()+10.0),
		).
			AssertFailure(t, "Auction listing for this item is already created.")

		otu.delistAllNFTForIOUAuction("user1")
	})

	t.Run("Should be able to sell and buy at auction even the seller didn't link provider correctly", func(t *testing.T) {

		otu.unlinkDandyProvider("user1").
			listNFTForIOUAuction("user1", id, price)

		otu.O.Tx("cancelMarketAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("ids", []uint64{id}),
		).
			AssertSuccess(t)
	})

	t.Run("Should be able to sell and buy at auction even the buyer didn't link receiver correctly", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			unlinkDandyReceiver("user2").
			auctionBidMarketIOU("user2", "user1", id, price+5.0).
			tickClock(400.0).
			saleItemListed("user1", "finished_completed", price+5.0).
			fulfillMarketAuctionIOU("user1", id, "user2", price+5.0).
			sendDandy("user1", "user2", id)
	})

	t.Run("Should be able to sell at auction", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", id, price+5.0).
			tickClock(400.0).
			saleItemListed("user1", "finished_completed", price+5.0).
			fulfillMarketAuctionIOU("user1", id, "user2", price+5.0).
			sendDandy("user1", "user2", id)

	})

	t.Run("Should be able to sell and buy at auction even the buyer is without the collection", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			destroyDandyCollection("user2").
			auctionBidMarketIOU("user2", "user1", id, price+5.0).
			tickClock(400.0).
			saleItemListed("user1", "finished_completed", price+5.0).
			fulfillMarketAuctionIOU("user1", id, "user2", price+5.0).
			sendDandy("user1", "user2", id)
	})

	t.Run("Should be able to cancel listing if the pointer is no longer valid", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", id, price+5.0).
			tickClock(400.0).
			saleItemListed("user1", "finished_completed", price+5.0).
			sendDandy("user3", "user1", id)

		otu.setUUID(600)

		otu.O.Tx("cancelMarketAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("ids", []uint64{id}),
		).
			AssertSuccess(t).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarketAuctionIOU.EnglishAuction", map[string]interface{}{
				"id":     id,
				"seller": otu.O.Address("user1"),
				"buyer":  otu.O.Address("user2"),
				"amount": 15.0,
				"status": "cancel_ghostlisting",
			}).
			AssertEvent(otu.T, "IOURedeemed", map[string]interface{}{
				"amount": 15.0,
			})

		otu.sendDandy("user1", "user3", id)

	})

	t.Run("Should not be able to list with price 0", func(t *testing.T) {

		otu.O.Tx(
			"listNFTForAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("nftAliasOrIdentifier", "Dandy"),
			WithArg("nftAliasOrIdentifier", "A.f8d6e0586b0a20c7.Dandy.NFT"),
			WithArg("id", id),
			WithArg("ftAliasOrIdentifier", "Flow"),
			WithArg("price", 0.0),
			WithArg("auctionReservePrice", price+5.0),
			WithArg("auctionDuration", 300.0),
			WithArg("auctionExtensionOnLateBid", 60.0),
			WithArg("minimumBidIncrement", 1.0),
			WithArg("auctionValidUntil", otu.currentTime()+10.0),
		).
			AssertFailure(t, "Auction start price should be greater than 0")
	})

	t.Run("Should not be able to list with invalid reserve price", func(t *testing.T) {

		otu.O.Tx(
			"listNFTForAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("nftAliasOrIdentifier", "A.f8d6e0586b0a20c7.Dandy.NFT"),
			WithArg("id", id),
			WithArg("ftAliasOrIdentifier", "Flow"),
			WithArg("price", price),
			WithArg("auctionReservePrice", price-5.0),
			WithArg("auctionDuration", 300.0),
			WithArg("auctionExtensionOnLateBid", 60.0),
			WithArg("minimumBidIncrement", 1.0),
			WithArg("auctionValidUntil", otu.currentTime()+10.0),
		).
			AssertFailure(t, "Auction reserve price should be greater than Auction start price")
	})

	t.Run("Should not be able to list with invalid time", func(t *testing.T) {

		otu.O.Tx(
			"listNFTForAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("nftAliasOrIdentifier", "Dandy"),
			WithArg("nftAliasOrIdentifier", "A.f8d6e0586b0a20c7.Dandy.NFT"),
			WithArg("id", id),
			WithArg("ftAliasOrIdentifier", "Flow"),
			WithArg("price", price),
			WithArg("auctionReservePrice", price+5.0),
			WithArg("auctionDuration", 300.0),
			WithArg("auctionExtensionOnLateBid", 60.0),
			WithArg("minimumBidIncrement", 1.0),
			WithArg("auctionValidUntil", otu.currentTime()-10.0),
		).
			AssertFailure(t, "Valid until is before current time")
	})

	t.Run("Should be able to sell at auction, buyer fulfill", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", id, price+5.0)

		otu.tickClock(400.0)

		otu.saleItemListed("user1", "finished_completed", price+5.0)
		otu.fulfillMarketAuctionIOUFromBidder("user2", id, price+5.0).
			sendDandy("user1", "user2", id)
	})

	t.Run("Should not be able to bid expired auction listing", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			tickClock(101.0)

		otu.O.Tx("bidMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("user", "user1"),
			WithArg("id", id),
			WithArg("amount", price),
		).
			AssertFailure(t, "This auction listing is already expired")

		otu.delistAllNFTForIOUAuction("user1")
	})

	t.Run("Should not be able to bid your own listing", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price)

		otu.O.Tx("bidMarketAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("user", "user1"),
			WithArg("id", id),
			WithArg("amount", price),
		).
			AssertFailure(t, "You cannot bid on your own resource")

		otu.delistAllNFTForIOUAuction("user1")
	})

	t.Run("Should return funds if auction does not meet reserve price", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", id, price+1.0).
			tickClock(400.0).
			saleItemListed("user1", "finished_failed", 11.0)

		buyer := "user2"
		name := "user1"

		otu.O.Tx("fulfillMarketAuctionIOU",
			WithSigner(name),
			WithArg("marketplace", "account"),
			WithArg("owner", name),
			WithArg("id", id),
		).
			AssertSuccess(t).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarketAuctionIOU.EnglishAuction", map[string]interface{}{
				"id":     id,
				"seller": otu.O.Address(name),
				"buyer":  otu.O.Address(buyer),
				"amount": 11.0,
				"status": "cancel_reserved_not_met",
			})

	})

	t.Run("Should be able to cancel the auction", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price)

		name := "user1"

		otu.O.Tx("cancelMarketAuctionIOU",
			WithSigner(name),
			WithArg("marketplace", "account"),
			WithArg("ids", []uint64{id}),
		).
			AssertSuccess(t).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarketAuctionIOU.EnglishAuction", map[string]interface{}{
				"id":     id,
				"seller": otu.O.Address(name),
				"amount": 10.0,
				"status": "cancel_listing",
			})

	})

	t.Run("Should not be able to cancel the auction if it is ended", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", id, price+5.0).
			tickClock(400.0).
			saleItemListed("user1", "finished_completed", price+5.0)

		name := "user1"

		otu.O.Tx("cancelMarketAuctionIOU",
			WithSigner(name),
			WithArg("marketplace", "account"),
			WithArg("ids", []uint64{id}),
		).
			AssertFailure(t, "Cannot cancel finished auction, fulfill it instead")

		otu.O.Tx("fulfillMarketAuctionIOU",
			WithSigner(name),
			WithArg("marketplace", "account"),
			WithArg("owner", name),
			WithArg("id", id),
		).
			AssertSuccess(t)

		otu.sendDandy("user1", "user2", id)

	})

	t.Run("Should not be able to fulfill a not yet live / ended auction", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price)

		otu.O.Tx("fulfillMarketAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("owner", "user1"),
			WithArg("id", id),
		).
			AssertFailure(t, "This auction is not live")

		otu.auctionBidMarketIOU("user2", "user1", id, price+5.0)

		otu.tickClock(100.0)

		otu.O.Tx("fulfillMarketAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("owner", "user1"),
			WithArg("id", id),
		).
			AssertFailure(t, "Auction has not ended yet")

		otu.delistAllNFTForIOUAuction("user1")

	})

	t.Run("Should return funds if auction is cancelled", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", id, price+1.0).
			saleItemListed("user1", "active_ongoing", 11.0).
			tickClock(2.0)

		buyer := "user2"
		name := "user1"

		otu.O.Tx("cancelMarketAuctionIOU",
			WithSigner(name),
			WithArg("marketplace", "account"),
			WithArg("ids", []uint64{id}),
		).
			AssertSuccess(t).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarketAuctionIOU.EnglishAuction", map[string]interface{}{
				"id":     id,
				"seller": otu.O.Address(name),
				"buyer":  otu.O.Address(buyer),
				"amount": 11.0,
				"status": "cancel_listing",
			})

	})

	t.Run("Should be able to bid and increase bid by same user", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", id, price+5.0).
			saleItemListed("user1", "active_ongoing", 15.0).
			increaseAuctioBidMarketIOU("user2", id, 5.0, 20.0).
			saleItemListed("user1", "active_ongoing", 20.0)

		otu.delistAllNFTForIOUAuction("user1")

	})

	t.Run("Should not be able to add bid that is not above minimumBidIncrement", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", id, price+preIncrement).
			saleItemListed("user1", "active_ongoing", price+preIncrement)

		otu.O.Tx("increaseBidMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("id", id),
			WithArg("amount", 0.1),
		).
			AssertFailure(t, "must be larger then previous bid+bidIncrement")

		otu.delistAllNFTForIOUAuction("user1")

	})

	/* Tests on Rules */
	t.Run("Should not be able to list after deprecated", func(t *testing.T) {

		otu.alterMarketOption("Auction", "deprecate")

		listingTx("listNFTForAuctionIOU",
			WithSigner("user1"),
			WithArg("id", id),
			WithArg("auctionValidUntil", otu.currentTime()+10.0),
		).
			AssertFailure(t, "Tenant has deprected mutation options on this item")

		otu.alterMarketOption("Auction", "enable")
	})

	t.Run("Should be able to bid, add bid , fulfill auction and delist after deprecated", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price)

		otu.alterMarketOption("Auction", "deprecate")

		otu.O.Tx("bidMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("user", "user1"),
			WithArg("id", id),
			WithArg("amount", price),
		).
			AssertSuccess(t)

		otu.O.Tx("increaseBidMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("id", id),
			WithArg("amount", price+10.0),
		).
			AssertSuccess(t)

		otu.tickClock(500.0)

		otu.O.Tx("fulfillMarketAuctionIOUFromBidder",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("id", id),
		).
			AssertSuccess(t)

		otu.alterMarketOption("Auction", "enable")

		listingTx("listNFTForAuctionIOU",
			WithSigner("user2"),
			WithArg("id", id),
			WithArg("auctionValidUntil", otu.currentTime()+10.0),
		).
			AssertSuccess(t)

		otu.auctionBidMarketIOU("user1", "user2", id, price+5.0)

		otu.alterMarketOption("Auction", "deprecate")

		otu.O.Tx("cancelMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("ids", []uint64{id}),
		).
			AssertSuccess(t)

		otu.alterMarketOption("Auction", "enable")
		otu.delistAllNFTForIOUAuction("user2").
			sendDandy("user1", "user2", id)

	})

	t.Run("Should no be able to list, bid, add bid , fulfill auction after stopped", func(t *testing.T) {

		otu.alterMarketOption("Auction", "stop")

		listingTx("listNFTForAuctionIOU",
			WithSigner("user1"),
			WithArg("id", id),
			WithArg("auctionValidUntil", otu.currentTime()+10.0),
		).
			AssertFailure(t, "Tenant has stopped this item")

		otu.alterMarketOption("Auction", "enable").
			listNFTForIOUAuction("user1", id, price).
			alterMarketOption("Auction", "stop")

		otu.O.Tx("bidMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("user", "user1"),
			WithArg("id", id),
			WithArg("amount", price),
		).
			AssertFailure(t, "Tenant has stopped this item")

		otu.alterMarketOption("Auction", "enable").
			auctionBidMarketIOU("user2", "user1", id, price+5.0).
			alterMarketOption("Auction", "stop")

		otu.O.Tx("increaseBidMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("id", id),
			WithArg("amount", price+10.0),
		).
			AssertFailure(t, "Tenant has stopped this item")

		otu.alterMarketOption("Auction", "stop")

		otu.tickClock(500.0)

		otu.O.Tx("fulfillMarketAuctionIOUFromBidder",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("id", id),
		).
			AssertFailure(t, "Tenant has stopped this item")

			/* Reset */
		otu.alterMarketOption("Auction", "enable")

		otu.O.Tx("fulfillMarketAuctionIOUFromBidder",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("id", id),
		).
			AssertSuccess(t)

		otu.delistAllNFTForIOUAuction("user1").
			sendDandy("user1", "user2", id)

	})

	t.Run("Should not be able to bid below listing price", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price)

		otu.O.Tx("bidMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("user", "user1"),
			WithArg("id", id),
			WithArg("amount", 1.0),
		).
			AssertFailure(t, "You need to bid more then the starting price of 10.00000000")

		otu.delistAllNFTForIOUAuction("user1")

	})

	t.Run("Should not be able to bid less the previous bidder", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", id, price+5.0)

		otu.O.Tx("bidMarketAuctionIOU",
			WithSigner("user3"),
			WithArg("marketplace", "account"),
			WithArg("user", "user1"),
			WithArg("id", id),
			WithArg("amount", 5.0),
		).
			AssertFailure(t, "bid 5.00000000 must be larger then previous bid+bidIncrement 16.00000000")

		otu.delistAllNFTForIOUAuction("user1")

	})

	/* Testing on Royalties */

	// platform 0.15
	// artist 0.05
	// find 0.025
	// tenant nil
	t.Run("Royalties should be sent to correspondence upon fulfill action", func(t *testing.T) {

		price = 5.0
		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			setProfile("user1").
			setProfile("user2").
			auctionBidMarketIOU("user2", "user1", id, price+5.0)

		otu.tickClock(500.0)

		otu.O.Tx("fulfillMarketAuctionIOUFromBidder",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("id", id),
		).
			AssertSuccess(t).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarket.RoyaltyPaid", map[string]interface{}{
				"address":     otu.O.Address("account"),
				"amount":      0.25,
				"id":          id,
				"royaltyName": "find",
				"tenant":      "find",
			}).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarket.RoyaltyPaid", map[string]interface{}{
				"address":     otu.O.Address("user1"),
				"amount":      0.5,
				"findName":    "user1",
				"id":          id,
				"royaltyName": "creator",
				"tenant":      "find",
			}).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarket.RoyaltyPaid", map[string]interface{}{
				"address":     otu.O.Address("account"),
				"amount":      0.25,
				"id":          id,
				"royaltyName": "find forge",
				"tenant":      "find",
			})

		otu.sendDandy("user1", "user2", id)

	})

	t.Run("Royalties of find platform should be able to change", func(t *testing.T) {

		price = 5.0
		otu.listNFTForIOUAuction("user1", id, price).
			saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", id, price+5.0).
			setFindCut(0.035)

		otu.tickClock(500.0)

		otu.O.Tx("fulfillMarketAuctionIOUFromBidder",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("id", id),
		).
			AssertSuccess(t).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarket.RoyaltyPaid", map[string]interface{}{
				"address":     otu.O.Address("account"),
				"amount":      0.35,
				"id":          id,
				"royaltyName": "find",
				"tenant":      "find",
			}).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarket.RoyaltyPaid", map[string]interface{}{
				"address":     otu.O.Address("user1"),
				"amount":      0.5,
				"findName":    "user1",
				"id":          id,
				"royaltyName": "creator",
				"tenant":      "find",
			}).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarket.RoyaltyPaid", map[string]interface{}{
				"address":     otu.O.Address("account"),
				"amount":      0.25,
				"id":          id,
				"royaltyName": "find forge",
				"tenant":      "find",
			})

		otu.sendDandy("user1", "user2", id)

	})

	t.Run("Should be able to ban user, user is only allowed to cancel listing.", func(t *testing.T) {
		price = 10.0

		ids := otu.mintThreeExampleDandies()

		otu.listNFTForIOUAuction("user1", ids[0], price).
			listNFTForIOUAuction("user1", ids[1], price).
			auctionBidMarketIOU("user2", "user1", ids[0], price+5.0).
			tickClock(400.0).
			profileBan("user1")

			// Should not be able to list
		listingTx("listNFTForAuctionIOU",
			WithSigner("user1"),
			WithArg("id", ids[2]),
			WithArg("auctionValidUntil", otu.currentTime()+10.0),
		).
			AssertFailure(t, "Seller banned by Tenant")

		otu.O.Tx("bidMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("user", "user1"),
			WithArg("id", ids[1]),
			WithArg("amount", price),
		).
			AssertFailure(t, "Seller banned by Tenant")

		otu.O.Tx("fulfillMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("owner", "user1"),
			WithArg("id", ids[0]),
		).
			AssertFailure(t, "Seller banned by Tenant")

		otu.O.Tx("cancelMarketAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("ids", []uint64{ids[1]}),
		).
			AssertSuccess(t)

		/* Reset */
		otu.removeProfileBan("user1")

		otu.O.Tx("fulfillMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("owner", "user1"),
			WithArg("id", ids[0]),
		).
			AssertSuccess(t)

	})

	t.Run("Should be able to ban user, user cannot bid NFT.", func(t *testing.T) {

		ids := otu.mintThreeExampleDandies()

		otu.listNFTForIOUAuction("user1", ids[0], price).
			listNFTForIOUAuction("user1", ids[1], price).
			auctionBidMarketIOU("user2", "user1", ids[0], price+5.0).
			tickClock(400.0).
			profileBan("user2")

		otu.O.Tx("bidMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("user", "user1"),
			WithArg("id", ids[1]),
			WithArg("amount", price),
		).
			AssertFailure(t, "Buyer banned by Tenant")

		otu.O.Tx("fulfillMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("owner", "user1"),
			WithArg("id", ids[0]),
		).
			AssertFailure(t, "Buyer banned by Tenant")

		/* Reset */
		otu.removeProfileBan("user2")

		otu.O.Tx("fulfillMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("owner", "user1"),
			WithArg("id", ids[0]),
		).
			AssertSuccess(t)

		otu.sendDandy("user1", "user2", ids[0])
		otu.delistAllNFTForIOUAuction("user2")
	})

	t.Run("Should emit previous bidder if outbid", func(t *testing.T) {

		otu.listNFTForIOUAuction("user1", id, price).
			auctionBidMarketIOU("user2", "user1", id, price+5.0)

		otu.O.Tx("bidMarketAuctionIOU",
			WithSigner("user3"),
			WithArg("marketplace", "account"),
			WithArg("user", "user1"),
			WithArg("id", id),
			WithArg("amount", 20.0),
		).
			AssertSuccess(t).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarketAuctionIOU.EnglishAuction", map[string]interface{}{
				"amount":        20.0,
				"id":            id,
				"buyer":         otu.O.Address("user3"),
				"previousBuyer": otu.O.Address("user2"),
				"status":        "active_ongoing",
			})

		otu.delistAllNFTForIOUAuction("user1")
	})

	t.Run("Should be able to list an NFT for auction and bid it with id != uuid", func(t *testing.T) {

		otu.registerDUCInRegistry().
			setDUCExampleNFT().
			sendExampleNFT("user1", "account")

		saleItem := otu.listExampleNFTForIOUAuction("user1", 0, price)

		otu.saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", saleItem[0], price+5.0).
			tickClock(400.0).
			saleItemListed("user1", "finished_completed", price+5.0).
			fulfillMarketAuctionIOU("user1", saleItem[0], "user2", price+5.0).
			sendExampleNFT("user1", "user2")

	})

	t.Run("Should be able to list an NFT for auction and bid it with DUC", func(t *testing.T) {

		otu.O.Tx("adminInitDUC",
			WithSigner("account"),
			WithArg("dapperAddress", "account"),
		).AssertSuccess(t)

		saleItemID := otu.listNFTForIOUAuctionDUC("user1", 0, price)

		otu.saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOUDUC("user2", "user1", saleItemID[0], price+5.0).
			tickClock(400.0).
			saleItemListed("user1", "finished_completed", price+5.0).
			fulfillMarketAuctionIOUDUC("user2", saleItemID[0], 15.0)

		otu.sendExampleNFT("user1", "user2")
	})

	t.Run("Should return fund in IOU for DUC bids when cancelled", func(t *testing.T) {

		saleItemID := otu.listNFTForIOUAuctionDUC("user1", 0, price)

		otu.saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOUDUC("user2", "user1", saleItemID[0], price+5.0)

		ducIOUId, err := otu.O.Tx("cancelMarketAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("ids", saleItemID),
		).
			AssertSuccess(t).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarketAuctionIOU.EnglishAuction", map[string]interface{}{
				"status": "cancel_listing",
			}).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindIOU.IOUDesposited", map[string]interface{}{
				"to": otu.O.Address("user2"),
			}).
			GetIdFromEvent("A.f8d6e0586b0a20c7.FindIOU.IOUDesposited", "uuid")

		assert.NoError(t, err)

		otu.O.Tx("redeemDapperIOU",
			WithSigner("user2"),
			WithPayloadSigner("account"),
			WithArg("id", ducIOUId),
		).
			AssertSuccess(t).
			AssertEvent(t, "IOURedeemed", map[string]interface{}{
				"type":   "A.f8d6e0586b0a20c7.DapperUtilityCoin.Vault",
				"amount": price + 5.0,
			})
	})

	t.Run("Should not be able to list soul bound items", func(t *testing.T) {
		otu.sendSoulBoundNFT("user1", "account")
		// set market rules
		otu.O.Tx("adminSetSellExampleNFTForFlow",
			overflow.WithSigner("find"),
			overflow.WithArg("tenant", "account"),
		)

		otu.O.Tx("listNFTForAuctionIOU",
			overflow.WithSigner("user1"),
			overflow.WithArg("marketplace", "account"),
			overflow.WithArg("nftAliasOrIdentifier", "A.f8d6e0586b0a20c7.ExampleNFT.NFT"),
			overflow.WithArg("id", 1),
			overflow.WithArg("ftAliasOrIdentifier", "Flow"),
			overflow.WithArg("price", price),
			overflow.WithArg("auctionReservePrice", price+5.0),
			overflow.WithArg("auctionDuration", 300.0),
			overflow.WithArg("auctionExtensionOnLateBid", 60.0),
			overflow.WithArg("minimumBidIncrement", 1.0),
			overflow.WithArg("auctionValidUntil", otu.currentTime()+100.0),
		).AssertFailure(t, "This item is soul bounded and cannot be traded")

	})

	t.Run("not be able to buy an NFT with changed royalties, but should be able to cancel listing", func(t *testing.T) {

		saleItem := otu.listExampleNFTForIOUAuction("user1", 0, price)

		otu.saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", saleItem[0], price+5.0).
			tickClock(400.0).
			saleItemListed("user1", "finished_completed", price+5.0)

		otu.changeRoyaltyExampleNFT("user1", 0)

		otu.O.Tx("fulfillMarketAuctionIOU",
			WithSigner("user2"),
			WithArg("marketplace", "account"),
			WithArg("owner", "user1"),
			WithArg("id", saleItem[0]),
		).
			AssertFailure(t, "The total Royalties to be paid is changed after listing.")

		otu.O.Tx("cancelMarketAuctionIOU",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("ids", []uint64{saleItem[0]}),
		).
			AssertSuccess(t).
			AssertEvent(t, "A.f8d6e0586b0a20c7.FindMarketAuctionIOU.EnglishAuction", map[string]interface{}{
				"status": "cancel_royalties_changed",
			})

	})

	t.Run("not be able to buy an NFT with changed royalties, but should be able to cancel listing", func(t *testing.T) {

		saleItem := otu.listExampleNFTForIOUAuction("user1", 0, price)

		otu.saleItemListed("user1", "active_listed", price).
			auctionBidMarketIOU("user2", "user1", saleItem[0], price+5.0).
			tickClock(400.0).
			saleItemListed("user1", "finished_completed", price+5.0)

		otu.changeRoyaltyExampleNFT("user1", 0)

		ids, err := otu.O.Script("getRoyaltyChangedIds",
			WithArg("marketplace", "account"),
			WithArg("user", "user1"),
		).
			GetAsJson()

		if err != nil {
			panic(err)
		}

		otu.O.Tx("relistMarketListings",
			WithSigner("user1"),
			WithArg("marketplace", "account"),
			WithArg("ids", ids),
		).
			AssertSuccess(t)

	})

}