use starknet::ContractAddress;
use gridlock::models::map::Map;

#[derive(Drop, Serde)]
#[dojo::model]
pub struct Player {
    #[key]
    pub address: ContractAddress,
    pub progress: Map,
    pub point: u256
}

#[derive(Drop, Copy, Serde, PartialEq)]
pub enum Move {
    UP,
    DOWN,
    LEFT,
    RIGHT,
}

impl MoveTypeFelt252 of Into<Move, felt252> {
    fn into(self: Move) -> felt252 {
        match self {
            Move::UP => 'up',
            Move::DOWN => 'down',
            Move::LEFT => 'left',
            Move::RIGHT => 'right',
        }
    }
}
