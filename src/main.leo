
// The 'exchange' program.
program exchange.aleo {

    record Ask {
        owner: address,
        order: Order,
    }

    record Bid {
        owner: address,
        order: Order,
    }

    record Transaction {
        owner: address,
        amount:u64,
        token:u64,//1u64 aleo,2u64 usdt
    }

    struct Order {
        addr: address,
        qty: u64,  // 总数量
        price: u64,
        count:u64, // 已成交数量 
        commission:u64,
        id:u64,
        order_type:u64, // 1u64 卖单, 2u64 买单
        status:u64      // 1u64 还没有成交,等单中..,2u64 部分成交,继续等单中..,3u64 全部成交,9u64 已取消
    }

    struct Account {
        Aleo:Token,
        Usdt:Token,
    }

    struct Token {
        amount: u64,
        lock: u64,
    }
    
    mapping accounts: address => Account;
    mapping orders: u64 => Order;
    mapping keys: u64 => u64;

    // sell.
    transition sell(qty :u64, price: u64,id: u64) -> Ask {
        let addr :address = self.caller;
        let order:Order = Order {
            addr: addr,
            qty:qty,
            price: price,
            count:0u64,
            commission:0u64,
            id:id,
            order_type:1u64,
            status:1u64,
        };
        return Ask {
            owner: addr,
            order: order, 
        } then finalize(order);
    }
    finalize sell(order: Order) {
        let commission_addr: address = aleo1wzgkaj0tdezlunuh52sc5e65c9n2w7r57sn8h7ph76vrr3mv8grslk9n57;
        let rate: u64 = 3u64; 
        let current_key:u64 = Mapping::get_or_use(keys, 1u64, 0u64);
        let count:u64 = 0u64;
        for i:u64 in 1u64..1024u64 {
            if (count < order.qty && i <= current_key) {
                let bid :Order = Mapping::get(orders,  i);
                if (bid.order_type == 2u64 && bid.price >= order.price && bid.status < 3u64) {
                    let available:u64 = order.qty - count;
                    if (bid.qty - bid.count < available) {
                        available = bid.qty - bid.count;
                    }

                    let bid_amount:u64 = count * order.price;
                    let bid_commission:u64 = (bid_amount * rate) / 10000u64;

                    let lock_amount:u64 = count * bid.price;
                    let lock_commission:u64 = (lock_amount * rate) / 10000u64;

                    let bid_status:u64 = bid.status;
                    if (bid.count == bid.qty) {
                        bid_status = 3u64;
                    } else {
                        bid_status = 2u64;
                    }
                    Mapping::set(orders,  i, Order {
                        addr: bid.addr,
                        qty:bid.qty,
                        price: bid.price,
                        count:bid.count + available,
                        commission:bid.commission + bid_commission,
                        id:bid.id,
                        order_type:bid.order_type,
                        status:bid_status,
                    });  
                    let act: Account = Mapping::get(accounts, bid.addr); 
                    Mapping::set(accounts,  bid.addr, Account {
                        Aleo : Token {
                            amount:act.Aleo.amount + available,
                            lock:act.Aleo.lock
                        },
                        Usdt:Token {
                            amount:act.Usdt.amount + (lock_amount - bid_amount) + (lock_commission - bid_commission),
                            lock:act.Usdt.lock - lock_amount - lock_commission,
                        }
                    });
                    act = Mapping::get(accounts, commission_addr);
                    Mapping::set(accounts,  commission_addr, Account {
                        Aleo : Token {
                            amount:act.Aleo.amount,
                            lock:act.Aleo.lock
                        },
                        Usdt:Token {
                            amount:act.Usdt.amount + bid_commission,
                            lock:act.Usdt.lock,
                        }
                    }); 
                    count = count + available;
                }
            }
        }
       
        let amount:u64 = count * order.price;
        let commission:u64 = (amount * rate) / 10000u64;

        let account: Account = Mapping::get(accounts, order.addr); 
        Mapping::set(accounts,  order.addr, Account {
            Aleo : Token {
                amount:account.Aleo.amount - order.qty,
                lock:account.Aleo.lock + (order.qty - count)
            },
            Usdt:Token {
                amount:account.Usdt.amount + amount - commission,
                lock:account.Usdt.lock,
            }
        }); 
        account = Mapping::get(accounts, commission_addr);
        Mapping::set(accounts,  commission_addr, Account {
            Aleo : Token {
                amount:account.Aleo.amount,
                lock:account.Aleo.lock
            },
            Usdt:Token {
                amount:account.Usdt.amount + commission,
                lock:account.Usdt.lock,
            }
        }); 

        let status:u64 = order.status;
        if (count == order.qty) { 
            status = 3u64;
        } else if (count > 0u64) {
            status = 2u64;
        }

        let key:u64 = current_key + 1u64;
        Mapping::set(keys,  1u64, key);
        Mapping::set(orders,  key, Order {
            addr: order.addr,
            qty:order.qty,
            price: order.price,
            count: count,
            commission:commission,
            id: order.id,
            order_type:2u64,
            status:status,
        }); 
    }
    // buy.
    transition buy(qty :u64, price: u64,id: u64) -> Bid {
        let addr :address = self.caller;
        let order:Order = Order {
            addr: addr,
            qty:qty,
            price: price,
            count:0u64,
            commission:0u64,
            id:id,
            order_type:2u64,
            status:1u64,
        };
        return Bid {
            owner: addr,
            order: order, 
        } then finalize(order);
    } 
    finalize buy(order: Order) {
        let commission_addr: address = aleo1wzgkaj0tdezlunuh52sc5e65c9n2w7r57sn8h7ph76vrr3mv8grslk9n57;
        let rate: u64 = 3u64;
        let current_key:u64 = Mapping::get_or_use(keys, 1u64, 0u64);
        let count:u64 = 0u64;
        let amount:u64 = 0u64;
        for i:u64 in 1u64..1024u64 {
            if (count < order.qty && i <= current_key) {
                let ask :Order = Mapping::get(orders,  i);
                if (ask.order_type == 1u64 && ask.price <= order.price && ask.status < 3u64) {
                    let available:u64 = order.qty - count;
                    if (ask.qty - ask.count < available) {
                        available = ask.qty - ask.count;
                    }
                    let ask_amount:u64 = available * order.price;
                    let ask_commission:u64 = (ask_amount * rate) / 10000u64;
                    let ask_status:u64 = ask.status;
                    if (ask.count == ask.qty) {
                        ask_status = 3u64;
                    } else {
                        ask_status = 2u64;
                    }
                    Mapping::set(orders,  i, Order {
                        addr: ask.addr,
                        qty:ask.qty,
                        price: ask.price,
                        count:ask.count + available,
                        commission:ask.commission + ask_commission,
                        id:ask.id,
                        order_type:ask.order_type,
                        status:ask_status,
                    }); 

                    let act: Account = Mapping::get(accounts, ask.addr); 
                    Mapping::set(accounts,  ask.addr, Account {
                        Aleo : Token {
                            amount:act.Aleo.amount,
                            lock:act.Aleo.lock - available
                        },
                        Usdt:Token {
                            amount:act.Usdt.amount + ask_amount - ask_commission,
                            lock:act.Usdt.lock,
                        }
                    });
                    act = Mapping::get(accounts, commission_addr);
                    Mapping::set(accounts,  commission_addr, Account {
                        Aleo : Token {
                            amount:act.Aleo.amount,
                            lock:act.Aleo.lock
                        },
                        Usdt:Token {
                            amount:act.Usdt.amount + ask_commission,
                            lock:act.Usdt.lock,
                        }
                    });
                    amount = amount + ask_amount;
                    count = count + available;
                }
            }
        }
       
        let commission:u64 = (amount * rate) / 10000u64;

        let lock_amount:u64 = (order.qty - count) * order.price;
        let lock_commission:u64 = (lock_amount * rate) / 10000u64;

        let account: Account = Mapping::get(accounts, order.addr); 
        Mapping::set(accounts,  order.addr, Account {
            Aleo : Token {
                amount:account.Aleo.amount + count,
                lock:account.Aleo.lock,
            },
            Usdt:Token {
                amount:account.Usdt.amount - amount - commission - lock_amount - lock_commission,
                lock:account.Usdt.lock + lock_amount + lock_commission,
            }
        });
        account = Mapping::get(accounts, commission_addr);
        Mapping::set(accounts,  commission_addr, Account {
            Aleo : Token {
                amount:account.Aleo.amount,
                lock:account.Aleo.lock
            },
            Usdt:Token {
                amount:account.Usdt.amount + commission,
                lock:account.Usdt.lock,
            }
        }); 

        let status:u64 = order.status;
        if (count == order.qty) { 
            status = 3u64;
        } else if (count > 0u64) {
            status = 2u64;
        }

        let key:u64 = current_key + 1u64;
        Mapping::set(keys,  1u64, key);
        Mapping::set(orders,  key, Order {
            addr: order.addr,
            qty:order.qty,
            price: order.price,
            count: count,
            commission:0u64,
            id: order.id,
            order_type:order.order_type,
            status:status,
        }); 
    }
    // cancel.
    transition cancel(id: u64) {
        let addr :address = self.caller;
       
        return then finalize(addr,id);
    } 
    finalize cancel(addr: address,id: u64) {
        let rate: u64 = 3u64;
        let current_key:u64 = Mapping::get_or_use(keys,  1u64, 0u64);
        for i:u64 in 1u64..1024u64 {
            if (i <= current_key) {
                let order :Order = Mapping::get(orders,  i);
                if (order.id == id && order.addr == addr && order.status < 3u64) { 
                    Mapping::set(orders,  i,Order {
                        addr: order.addr,
                        qty:order.qty,
                        price: order.price,
                        count: order.count,
                        commission:order.commission,
                        id: order.id,
                        order_type:order.order_type,
                        status:9u64,
                    });

                    if (order.order_type == 2u64) {

                        let lock_amount:u64 = (order.qty - order.count) * order.price;
                        let lock_commission:u64 = (lock_amount * rate) / 10000u64;

                        let account: Account = Mapping::get(accounts, order.addr); 
                        Mapping::set(accounts,  order.addr, Account {
                            Aleo : Token {
                                amount:account.Aleo.amount,
                                lock:account.Aleo.lock,
                            },
                            Usdt:Token {
                                amount:account.Usdt.amount + lock_amount + lock_commission,
                                lock:account.Usdt.lock - lock_amount - lock_commission,
                            }
                        });
                    }
                }
            }
        }
    }
    // recharge.
    transition recharge(amount: u64,token: u64) -> Transaction {
        let addr :address = self.caller;
        return Transaction {
            owner: addr,
            amount:amount,
            token: token,
        } then finalize(addr, amount,token);
    }
    finalize recharge(addr: address, amount: u64,token: u64) {
        let account: Account = Mapping::get_or_use(accounts, addr, Account{
            Aleo:Token{
                amount:0u64,
                lock:0u64,
            },
            Usdt:Token{
                amount:0u64,
                lock:0u64,
            },
        });
        let aleo_amount:u64 = account.Aleo.amount;
        let usdt_amount:u64 = account.Usdt.amount;
        if(token == 1u64) {
            aleo_amount = aleo_amount + amount;
        } else if(token == 2u64) {
            usdt_amount = usdt_amount + amount;
        }

        Mapping::set(accounts, addr, Account{
            Aleo:Token{
                amount:aleo_amount,
                lock:account.Aleo.lock,
            },
            Usdt:Token{
                amount:usdt_amount,
                lock:account.Usdt.lock,
            },
        });
    }
    // withdraw 
    transition withdraw(amount: u64,token: u64) -> Transaction {
        let addr :address = self.caller;
        return Transaction {
            owner: addr,
            amount:amount,
            token: token,
        } then finalize(addr, amount,token);
    }
    finalize withdraw(addr: address, amount: u64,token: u64) {
        let account: Account = Mapping::get_or_use(accounts, addr, Account{
            Aleo:Token{
                amount:0u64,
                lock:0u64,
            },
            Usdt:Token{
                amount:0u64,
                lock:0u64,
            },
        });
        let aleo_amount:u64 = account.Aleo.amount;
        let usdt_amount:u64 = account.Usdt.amount;
        if(token == 1u64) {
            aleo_amount = aleo_amount - amount;
        } else if(token == 2u64) {
            usdt_amount = usdt_amount - amount;
        }

        Mapping::set(accounts, addr, Account{
            Aleo:Token{
                amount:aleo_amount,
                lock:account.Aleo.lock,
            },
            Usdt:Token{
                amount:usdt_amount,
                lock:account.Usdt.lock,
            },
        });
    }

    // commission
    function calculate_commission(amount: u64) -> u64 {
        let rate: u64 = 3u64; 
        return (amount * rate) / 10000u64;
    }
}
