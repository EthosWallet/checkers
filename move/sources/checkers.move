module ethos::checkers {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::event;
    use sui::transfer;
    use std::vector;
    use std::option::{Self, Option};
    use ethos::checker_board::{Self, CheckerBoard};

    #[test_only]
    friend ethos::checkers_tests;

    const EINVALID_PLAYER: u64 = 0;
    const EGAME_OVER: u64 = 0;

    const PLAYER1: u8 = 1;
    const PLAYER2: u8 = 2;

    struct CheckersGame has key, store {
        id: UID,
        name: String,
        description: String,
        url: Url,
        player1: address,
        player2: address,
        moves: vector<CheckersMove>,
        boards: vector<CheckerBoard>,
        current_player: address,
        winner: Option<address>
    }

    struct CheckersPlayerCap has key, store {
        id: UID,
        game_id: ID,
        name: String,
        description: String,
        url: Url
    }

    struct CheckersMove has store {
        from_row: u64,
        from_column: u64,
        to_row: u64,
        to_column: u64,
        player: address,
        player_number: u8,
        epoch: u64
    }

    struct NewCheckersGameEvent has copy, drop {
        game_id: ID,
        player1: address,
        player2: address,
        board_spaces: vector<vector<Option<u8>>>
    }

    struct CheckersMoveEvent has copy, drop {
        game_id: ID,
        from_row: u64,
        from_column: u64,
        to_row: u64,
        to_column: u64,
        player: address,
        player_number: u8,
        board_spaces: vector<vector<Option<u8>>>,
        epoch: u64
    }

    struct CheckersGameOverEvent has copy, drop {
        game_id: ID,
        winner: address
    }

    public entry fun create_game(player2: address, ctx: &mut TxContext) {
        let new_board = checker_board::new();
        create_game_with_board(player2, new_board, ctx);
    }
    
    public(friend) fun create_game_with_board(player2: address, board: CheckerBoard, ctx: &mut TxContext) {
        let game_uid = object::new(ctx);
        let player1 = tx_context::sender(ctx);
        
        let name = string::utf8(b"Ethos Checkers");
        let description = string::utf8(b"Checkers - built on Sui  - by Ethos");
        let url = url::new_unsafe_from_bytes(b"https://arweave.net/jTdGvMfpIpLdXofNAjbl0l9_PuFopa0xpMXYwfbIaS4");
        
        let game = CheckersGame {
            id: game_uid,
            name,
            description,
            url,
            player1,
            player2,
            moves: vector[],
            boards: vector[board],
            current_player: player1,
            winner: option::none()
        };
        
        let game_id = object::uid_to_inner(&game.id);
        
        let player1_cap = CheckersPlayerCap {
            id: object::new(ctx),
            game_id,
            name,
            description,
            url,
        };

        let player2_cap = CheckersPlayerCap {
            id: object::new(ctx),
            game_id,
            name,
            description,
            url,
        };

        let board_spaces = *checker_board::spaces(&board);
        event::emit(NewCheckersGameEvent {
            game_id,
            player1,
            player2,
            board_spaces
        });
        
        transfer::share_object(game);
        transfer::transfer(player1_cap, player1);
        transfer::transfer(player2_cap, player2);
    }

    public entry fun make_move(game: &mut CheckersGame, from_row: u64, from_column: u64, to_row: u64, to_column: u64, ctx: &mut TxContext) {
        let player = tx_context::sender(ctx);  
        assert!(game.current_player == player, EINVALID_PLAYER);
        assert!(option::is_none(&game.winner), EGAME_OVER);

        let player_number = PLAYER1; 
        if (game.player2 == player) {
            player_number = PLAYER2;
        };

        let mut_board = current_board_mut(game);
        let new_board = *mut_board;
        {
            checker_board::modify(&mut new_board, player_number, from_row, from_column, to_row, to_column);
        };
        
        if (player == game.player1) {
            game.current_player = *&game.player2;
        } else {
            game.current_player = *&game.player1;
        };

        let game_id = object::uid_to_inner(&game.id);
        let board_spaces = *checker_board::spaces(&new_board);
        let epoch = tx_context::epoch(ctx);
        event::emit(CheckersMoveEvent {
            game_id,
            from_row,
            from_column,
            to_row,
            to_column,
            player,
            player_number,
            board_spaces,
            epoch
        });

        if (*checker_board::game_over(&new_board)) {
            option::fill(&mut game.winner, player);

            event::emit(CheckersGameOverEvent {
                game_id,
                winner: player
            });
        };

        let new_move = CheckersMove {
          from_row,
          from_column,
          to_row,
          to_column,
          player,
          player_number,
          epoch
        };

        vector::push_back(&mut game.moves, new_move);
        vector::push_back(&mut game.boards, new_board);
    }

    public fun game_id(game: &CheckersGame): &UID {
        &game.id
    }

    public fun player1(game: &CheckersGame): &address {
        &game.player1
    }

    public fun player2(game: &CheckersGame): &address {
        &game.player2
    }

    public fun move_count(game: &CheckersGame): u64 {
        vector::length(&game.moves)
    }

    public fun board_at(game: &CheckersGame, index: u64): &CheckerBoard {
        vector::borrow(&game.boards, index)
    }

    public fun board_at_mut(game: &mut CheckersGame, index: u64): &mut CheckerBoard {
        vector::borrow_mut(&mut game.boards, index)
    }

    public fun current_board(game: &CheckersGame): &CheckerBoard {
        let last_board_index = vector::length(&game.boards) - 1;
        board_at(game, last_board_index)
    }

    public fun current_board_mut(game: &mut CheckersGame): &mut CheckerBoard {
        let last_board_index = vector::length(&game.boards) - 1;
        board_at_mut(game, last_board_index)
    }

    public fun piece_at(game: &CheckersGame, row: u64, column: u64): &u8 {
        let board = current_board(game);
        checker_board::piece_at(board, row, column)
    }

    public fun current_player(game: &CheckersGame): &address {
        &game.current_player
    }

    public fun player_cap_game_id(player_cap: &CheckersPlayerCap): &ID {
        &player_cap.game_id
    }

    public fun winner(game: &CheckersGame): &Option<address> {
        &game.winner
    }

    public fun game_over(game: &CheckersGame): &bool {
        let board = current_board(game);
        checker_board::game_over(board)
    }
}