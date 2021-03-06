//
//  TradeEngine.swift
//  SwiftTradeEngine
//
//  Created by Eugen Fedchenko on 5/23/17.
//
//

import Foundation

class TradeEngine : TradeEngineProtocol {
    
    init(symbols: [OBString], factory: OrderBookFactory) {
        self.books = symbols.reduce([:], { (books, s) -> [OBString : OrderBookProtocol] in
            return books + (s, factory.createOrderBook())
        })
        
        self.books.values.forEach { (book) in
            var p = book
            p.tradeHandler = { [weak self] (event) in
                self?.handleEvent(event: event)
            }
        }
    }
    
    // MARK: TradeEngineProtocol
    
    var tradeHandler: TradeHandler?
    
    func createMarketOrder(side: OrderSide, symbol: String, trader: String, shares: Quantity) throws -> Order {
        guard let book = getBook(forSymbol: symbol) else {
            throw EngineError.UnknownSymbol(symbol: symbol)
        }
        
        guard let price = side == .buy ? book.topBuyOrder?.price : book.topSellOrder?.price else {
            throw EngineError.EmptyMarket(symbol: symbol)
        }
        
        let id = nextID()
        let order = Order(id: id, side: side, symbol: symbol, trader: trader, price: price, shares: shares)
        
        orders[id] = order
        book.add(order: order)
        
        return order
    }
    
    func createLimitOrder(side: OrderSide, symbol: String, trader: String, price: Money, shares: Quantity) throws -> Order {
        guard let book = getBook(forSymbol: symbol) else {
            throw EngineError.UnknownSymbol(symbol: symbol)
        }
        
        
        let id = nextID()
        let order = Order(id: id, side: side, symbol: symbol, trader: trader, price: price, shares: shares)
        
        orders[id] = order
        book.add(order: order)
        
        return order
    }
    
    func cancel(orderById id: OrderID) {
        if let order = orders[id], let book = getBook(forSymbol: order.symbol) {
            orders.removeValue(forKey: id)
            book.cancel(orderById: id)
        }
    }
    
    func sellMin(forSymbol symbol: String) -> Money? {
        return getBook(forSymbol: symbol)?.topSellOrder?.price
    }
    
    func buyMax(forSymbol symbol: String) -> Money? {
        return getBook(forSymbol: symbol)?.topBuyOrder?.price
    }
    
    // MARK: private
    
    private func getBook(forSymbol sym: OBString) -> OrderBookProtocol? {
        return books[sym]
    }
    
    private func nextID() -> OrderID {
        currentID += 1
        return currentID
    }
    
    //
    
    private func handleEvent(event: TradeEvent) {
        if let handler = tradeHandler {
            handler(event)
        }
    }
    
    // MARK:
    
    private let books: [OBString : OrderBookProtocol]
    private var currentID: OrderID = 0
    private var orders = Dictionary<OrderID, Order>()
}
