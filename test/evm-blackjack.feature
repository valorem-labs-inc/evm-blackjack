Feature: EVM Blackjack

    As a Player or a Dealer,
    I want to play blackjack on-chain,
    so that I can be assured of fairness while participating in an enjoyable online game of skill.

    Scenario: Player sits at table
        Given There are 3 live tables
        And House has 1000000 CHIP
        #And Player has 1 ETH in her wallet
        When Player sits at table
        #Then Player should have 0.99 ETH in her wallet
        And Player should have 1000 CHIP
        And House should have 999000 CHIP
        And Player should be sitting at Table 4
        And Table 4 should be "Ready for Bet"

    Scenario: Player places bet
        Given Player is sitting at Table 4
        When Player places a bet of 10 CHIP
        Then Player should have 990 CHIP in their wallet
        And Table 4 should be "Ready for Deal"

    @Revert
    Scenario: Player places bet below table minimum

    @Revert
    Scenario: Player places bet above table maximum

    Scenario: Dealer deals initial hands
        Given Player is sitting at Table 4
        And Player has placed a bet of 10 CHIP
        And Table 4 is "Ready for Deal"
        When Dealer deals initial hands
        Then Player should have 2 cards
        And Dealer should have 1 card
        And Table 4 should be "Ready for Player Action"

    Scenario: Player receives natural
        Given Player is sitting at Table 4
        And Player is sitting at Table 4
        And Player has 990 CHIP
        And House has 999000 CHIP
        And Player bet 10 CHIP
        And Player received AT
        And Dealer received any card
        Then Player should have 1015 CHIP (paying out 3:2)
        And House should have 998985 CHIP
        And Table 4 should be "Ready for Bet"

    Scenario: Player buys insurance and dealer receives natural
        Given Player is sitting at Table 4
        And Player has 990 CHIP
        And House has 999000 CHIP
        And Player bet 10 CHIP
        And Player received any two cards
        And Dealer received A
        When Player buys insurance
        Then TODO

    Scenario: Player buys insurance and dealer does not receive natural

    Scenario: Player declines to buy insurance
        Given Player is sitting at Table 4
        And Player has 990 CHIP
        And House has 999000 CHIP
        And Player bet 10 CHIP
        And Player received any two cards
        And Dealer received A
        When Player declines to buy insurance
        Then Table 4 should be "Ready for Player Action"

    Scenario: Player Action - Player splits Aces
        Given Player is sitting at Table 4
        And Player bet 10 CHIP
        And Player received AA
        And Dealer received any card
        When Player splits
        Then TODO

    Scenario: Player Action - Player splits non-Ace pair
        Given Player is sitting at Table 4
        And Player bet 10 CHIP
        And Player received TT
        And Dealer received any card
        When Player splits
        Then TODO

    Scenario: Player Action - Player doubles down
        Given Player is sitting at Table 4
        And Player has 990 CHIP
        And Player bet 10 CHIP
        And Player received 83
        And Dealer received any card
        When Player doubles down
        Then Player should have 980 CHIP
        And Player bet should be 20 CHIP
        And Dealer should deal 1 additional card to Player

    Scenario: Player Action - Player hits (initial)
        Given Player is sitting at Table 4
        And Player received 54
        And Dealer received any card
        When Player hits
        Then Dealer should deal 1 additional card to Player

    Scenario: Player Action - Player hits (subsequent)
        Given Player is sitting at Table 4
        And Player received 54
        And Dealer received any card
        And Player hit and received 3
        When Player hits
        Then Dealer should deal 1 additional card to Player

    Scenario: Player Action - Player stands (initial)
        Given Player is sitting at Table 4
        And Player received T8
        And Dealer received any card
        When Player stands
        Then Table 4 should be "Ready for Dealer Action"

    Scenario: Player Action - Player stands (subsequent)
        Given Player is sitting at Table 4
        And Player received 85
        And Dealer received any card
        And Player hit and received 4
        When Player stands
        Then Table 4 should be "Ready for Dealer Action"

    Scenario: Player busts
        Given Player is sitting at Table 4
        And Player has 990 CHIP
        And House has 999000 CHIP
        And Player bet 10 CHIP
        When Player has a hard total of greater than 21
        Then Table 4 should be "Ready for Bet"
        And Player should have 990 CHIP
        And House should have 999010 CHIP

    Scenario: Dealer receives natural
        Given Player is sitting at Table 4
        And Player has 990 CHIP
        And House has 999000 CHIP
        And Player bet 10 CHIP
        And Player received T8
        And Dealer received T
        And Player stood
        When Dealer deals themselves A
        Then Table 4 should be "Ready for Bet"
        And Player should have 990 CHIP
        And House should have 999010 CHIP

    Scenario: Dealer hits
        Given Player is sitting at Table 4
        And Player bet 10 CHIP
        And Player received T8
        And Dealer received T
        And Player stood
        When Dealer deals any card for a total of less than or equal to 16
        Then Dealer hits and Dealer should deal 1 additional card to themselves

    Scenario: Dealer stands
        Given Player is sitting at Table 4
        And Player bet 10 CHIP
        And Player received T8
        And Dealer received T
        And Player stood
        When Dealer deals any card for a total of greater than 16
        Then Dealer stands
        And Table 4 should be "Ready for Payouts"

    Scenario: Dealer busts
        Given Player is sitting at Table 4
        And Player has 990 CHIP
        And House has 999000 CHIP
        And Player bet 10 CHIP
        And Player received T8
        And Dealer received T
        And Player stood
        And Dealer deals themselves 3
        When Dealer has a hard total of greater than 21
        Then Table 4 should be "Ready for Bet"
        And Player should have 1010 CHIP
        And House should have 998990 CHIP

    Scenario: Dealer handles payouts when Player has best hand
        Given Player has 990 CHIP
        And House has 999000 CHIP
        And Player bet 10 CHIP
        And Player has the best hand
        When Dealer handles payouts
        Then Player should have 1010 CHIP
        And House shoud have 999000 CHIP

    Scenario: Dealer handles payouts when Dealer has best hand
        Given Player has 990 CHIP
        And House has 999000 CHIP
        And Player bet 10 CHIP
        And Player has the best hand
        When Dealer handles payouts
        Then Player should have 990 CHIP
        And House shoud have 999010 CHIP

    Scenario: Player leaves table
        Given Table 4 is "Ready for Bet"
        When Player leaves table
        Then TODO
