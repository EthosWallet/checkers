module ethos::checker_board {
    use std::option::{Self, Option};
    use std::vector;
    
    friend ethos::checkers;

    #[test_only]
    friend ethos::checker_board_tests;

    #[test_only]
    friend ethos::checkers_tests;

    const EMPTY: u8 = 0;
    const PLAYER1: u8 = 1;
    const PLAYER2: u8 = 2;

    const ROW_COUNT: u64 = 8;
    const COLUMN_COUNT: u64 = 8;
    const PLAYER_PIECES: u64 = 12;

    const EEMPTY_SPACE: u64 = 0;
    const EBAD_DESTINATION: u64 = 1;
    const EOCCUPIED_SPACE: u64 = 2;
    const EBAD_JUMP: u64 = 3;
    const EINVALID_PLAYER: u64 = 4;
    
    struct CheckerBoard has store, copy, drop {
        spaces: vector<vector<Option<u8>>>,
        game_over: bool
    }

    struct SpacePosition has copy, drop {
        row: u64,
        column: u64
    }

    struct PlayerPositions has copy, drop {
        player1: vector<SpacePosition>,
        player2: vector<SpacePosition>,
    }

    struct PlayerCounts has copy, drop {
        player1: u64,
        player2: u64
    }

    struct MoveEffects has drop {
        jumps: vector<SpacePosition>
    }

    public(friend) fun new(): CheckerBoard {
        let spaces = vector[];

        let i=0;
        while (i < ROW_COUNT) {
            let row = vector[];

            let j=0;
            while (j < COLUMN_COUNT) {
                if (valid_space(i, j)) {
                    if (i < 3) {
                        vector::push_back(&mut row, option::some(PLAYER1))
                    } else if (i > 4) {
                        vector::push_back(&mut row, option::some(PLAYER2))
                    } else {
                        vector::push_back(&mut row, option::some(EMPTY))
                    }        
                } else {
                    vector::push_back(&mut row, option::none())
                };

                j = j + 1;
            };

            vector::push_back(&mut spaces, row);

            i = i + 1;
        };

        let game_board = create_board(spaces);

        game_board 
    }
 
    public(friend) fun create_board(spaces: vector<vector<Option<u8>>>): CheckerBoard {
        CheckerBoard { 
            spaces, 
            game_over: false
        }
    }

    public(friend) fun modify(board: &mut CheckerBoard, player_number: u8, from_row: u64, from_col: u64, to_row: u64, to_col: u64): bool {
        let piece = piece_at(board, from_row, from_col);
        let move_effects = analyze_move(board, player_number, piece, from_row, from_col, to_row, to_col);
        
        let old_space = space_at_mut(board, from_row, from_col);
        let piece = option::swap(old_space, EMPTY);

        let new_space = space_at_mut(board, to_row, to_col);
        option::swap(new_space, piece);

        let jump_index = 0;
        let jumps_count = vector::length(&move_effects.jumps);
        while (jump_index < jumps_count) {
            let position = vector::borrow(&move_effects.jumps, jump_index);
            let jump_space = space_at_mut(board, position.row, position.column);
            option::swap(jump_space, EMPTY);

            jump_index = jump_index + 1;
        };

        let counts = player_counts(board);
        if (counts.player1 == 0 || counts.player2 == 0) {
            board.game_over = true;
        };

        true
    }
    
    public fun row_count(): u64 {
        ROW_COUNT
    }

    public fun column_count(): u64 {
        COLUMN_COUNT
    }

    fun spaces_at(spaces: &vector<vector<Option<u8>>>, row_index: u64, column_index: u64): &Option<u8> {
        let row = vector::borrow(spaces, row_index);
        vector::borrow(row, column_index)
    }

    fun spaces_at_mut(spaces: &mut vector<vector<Option<u8>>>, row_index: u64, column_index: u64): &mut Option<u8> {
        let row = vector::borrow_mut(spaces, row_index);
        vector::borrow_mut(row, column_index)
    }

    public(friend) fun spaces(board: &CheckerBoard): &vector<vector<Option<u8>>> {
        &board.spaces
    }

    public(friend) fun space_at(board: &CheckerBoard, row_index: u64, column_index: u64): &Option<u8> {
        spaces_at(&board.spaces, row_index, column_index)
    }

    public(friend) fun space_at_mut(board: &mut CheckerBoard, row_index: u64, column_index: u64): &mut Option<u8> {
        spaces_at_mut(&mut board.spaces, row_index, column_index)
    }

    public(friend) fun piece_at(board: &CheckerBoard, row: u64, column: u64): &u8 {
        option::borrow(space_at(board, row, column))
    }

    public(friend) fun game_over(board: &CheckerBoard): &bool {
        &board.game_over
    }

    public(friend) fun empty_space_positions(game_board: &CheckerBoard): vector<SpacePosition> {
        let empty_spaces = vector<SpacePosition>[];

        let row = 0;
        while (row < ROW_COUNT) {
          let column = 0;
          while (column < COLUMN_COUNT) {
            let space = space_at(game_board, row, column);
            if (option::contains(space, &EMPTY)) {
              vector::push_back(&mut empty_spaces, SpacePosition { row, column })
            };
            column = column + 1;
          };
          row = row + 1;
        };

        empty_spaces
    }

    public(friend) fun empty_space_count(game_board: &CheckerBoard): u64 {
        vector::length(&empty_space_positions(game_board))
    }

    public(friend) fun player_positions(game_board: &CheckerBoard): PlayerPositions {
        let positions1 = vector<SpacePosition>[];
        let positions2 = vector<SpacePosition>[];

        let row = 0;
        while (row < ROW_COUNT) {
            let column = 0;
            while (column < COLUMN_COUNT) {
                let space = space_at(game_board, row, column);
                if (option::contains(space, &PLAYER1)) {
                    vector::push_back(&mut positions1, SpacePosition { row, column })
                } else if (option::contains(space, &PLAYER2)) {
                    vector::push_back(&mut positions2, SpacePosition { row, column })
                };
                column = column + 1;
            };
            row = row + 1;
        };

        PlayerPositions {
            player1: positions1,
            player2: positions2
        }
    }

    public(friend) fun player_counts(game_board: &CheckerBoard): PlayerCounts {
        let positions = player_positions(game_board);
        PlayerCounts {
            player1: vector::length(&positions.player1),
            player2: vector::length(&positions.player2)
        }
    }


    fun valid_space(row: u64, column: u64): bool {
        if (row % 2 == 1) {
            column % 2 == 0
        } else {
            column % 2 == 1
        }
    }

    fun analyze_move(board: &CheckerBoard, player_number: u8, piece: &u8, from_row: u64, from_col: u64, to_row: u64, to_col: u64): MoveEffects {
        assert!(piece == &player_number, EINVALID_PLAYER);
        assert!(to_row < ROW_COUNT, EBAD_DESTINATION);
        assert!(to_col < COLUMN_COUNT, EBAD_DESTINATION);
        
        let move_effects = MoveEffects {
            jumps: vector[]
        };

        let new_space = space_at(board, to_row, to_col);

        let player1_move = (piece == &PLAYER1);
        let player2_move = (piece == &PLAYER2);
        assert!(player1_move || player2_move, EEMPTY_SPACE);

        if (player1_move) {
            assert!(to_row > from_row, EBAD_DESTINATION);
        } else {
            assert!(to_row < from_row, EBAD_DESTINATION);
        };

        assert!(option::contains(new_space, &EMPTY), EOCCUPIED_SPACE);

        let jump = (player1_move && from_row + 2 == to_row) || 
                   (player2_move && from_row - 2 == to_row);

        let double_jump = (player1_move && from_row + 4 == to_row) || 
                          (player2_move && from_row >= 4 && from_row - 4 == to_row);

        if (jump || double_jump) {
            let over_row = from_row + 1;
            let over_col = from_col + 1;
            let over_piece = PLAYER2;

            let landing_row = from_row + 2;
            let landing_col = from_row + 2;

            if (player2_move) {
                over_row = from_row - 1;
                over_piece = PLAYER1;
                landing_row = from_row - 2;
            };
            
            if (from_col > to_col) {
                over_col = from_col - 1;
                landing_col = from_col - 2;
            } else if (from_col == to_col) {
                let over_option1 = piece_at(board, over_row, over_col);
                if (over_option1 != &over_piece) {
                    over_col = from_col - 1;
                    landing_col = from_col - 2;
                }
            };
            
            assert!(piece_at(board, over_row, over_col) == &over_piece, EBAD_JUMP);

            let over_position = SpacePosition {
                row: over_row,
                column: over_col
            };
            vector::push_back(&mut move_effects.jumps, over_position);

            if (double_jump) {
                let double_jump_effects = analyze_move(
                    board, 
                    player_number,
                    piece,
                    landing_row, 
                    landing_col, 
                    to_row, 
                    to_col
                );

                vector::append(&mut move_effects.jumps, double_jump_effects.jumps);
            }
        } else { 
            if (player1_move) {
                assert!(from_row + 1 == to_row, EBAD_DESTINATION);
            } else {
                assert!(from_row - 1 == to_row, EBAD_DESTINATION);
            };
            assert!(from_col + 1 == to_col || from_col == to_col + 1, EBAD_DESTINATION);
        };

        move_effects
    }

}

