//SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IShuffle.sol";

contract Shuffle is IShuffle, Ownable {
    using Pairing for *;
    using CurveBabyJubJub for *;

    uint256 public constant override INVALID_CARD_INDEX = 999999;

    IShuffleEncryptVerifier public shuffleEncryptVerifier;
    IDecryptVerifier public decryptVerifier;
    address gameContract;

    // The mapping of game id => Number of players
    mapping(uint256 => uint256) public numPlayers;

    // The mapping of game id => deck
    mapping(uint256 => Deck) decks;

    // Initial deck which is the same for all games
    Deck initialDeck;

    // The mapping of game id => card deal status
    mapping(uint256 => CardDeal) cardDeals;

    // The mapping of game id => player information
    mapping(uint256 => PlayerInfo) playerInfos;

    // The mapping of game id => index of the current player to take action
    mapping(uint256 => uint256) public playerIndexes;

    // The mapping of game id => current state of the card game
    mapping(uint256 => State) public states;

    modifier inDealingPhase(uint256 gameId) {
        require(
            states[gameId] == State.DealingCard,
            "Contract must be in dealing phase to call this function"
        );
        _;
    }

    modifier onlyGameContract() {
        require(gameContract == msg.sender, "Caller is not game contract");
        _;
    }

    constructor(address shuffleEncryptContract_, address decryptContract_) {
        shuffleEncryptVerifier = IShuffleEncryptVerifier(
            shuffleEncryptContract_
        );
        decryptVerifier = IDecryptVerifier(decryptContract_);

        initDeck(0);
    }

    // Sets game settings.
    function setGameSettings(
        uint256 numPlayers_,
        uint256 gameId
    ) external override onlyGameContract {
        numPlayers[gameId] = numPlayers_;
        playerIndexes[gameId] = 0;
        states[gameId] = State.Registration;
    }

    // Sets game contract.
    function setGameContract(address gameContract_) external onlyOwner {
        gameContract = gameContract_;
    }

    // Initializes deck before shuffling.
    function initDeck(uint256 gameId) internal {
        Deck memory deck;
        for (uint256 i = 0; i < 5; i++) {
            deck.X0[i] = 0;
        }
        deck.X1[
                0
            ] = 5299619240641551281634865583518297030282874472190772894086521144482721001553;
        deck.X1[
                1
            ] = 10031262171927540148667355526369034398030886437092045105752248699557385197826;
        deck.X1[
                2
            ] = 2763488322167937039616325905516046217694264098671987087929565332380420898366;
        deck.X1[
                3
            ] = 12252886604826192316928789929706397349846234911198931249025449955069330867144;
        deck.X1[
                4
            ] = 11480966271046430430613841218147196773252373073876138147006741179837832100836;

        deck.Selector[0] = 31;
        deck.Selector[1] = 10;
        // `gameId = 0` is reserved for Not-In-Game.
        if (gameId == 0) {
            initialDeck = deck;
        } else {
            decks[gameId] = deck;
        }
    }

    // Registers a player with the `permanentAccount`, public key `pk`, and `gameId`.
    function register(
        address permanentAccount,
        uint256[2] memory pk,
        uint256 gameId
    ) external override onlyGameContract {
        require(states[gameId] == State.Registration, "Not in register phase");
        require(CurveBabyJubJub.isOnCurve(pk[0], pk[1]), "Invalid public key");
        playerInfos[gameId].playerAddr.push(permanentAccount);
        playerInfos[gameId].playerPk.push(pk[0]);
        playerInfos[gameId].playerPk.push(pk[1]);
        playerIndexes[gameId] += 1;
        if (playerIndexes[gameId] == numPlayers[gameId]) {
            states[gameId] = State.ShufflingDeck;
            playerIndexes[gameId] = 0;
            playerInfos[gameId].aggregatedPk = [
                playerInfos[gameId].playerPk[0],
                playerInfos[gameId].playerPk[1]
            ];
            for (uint256 i = 1; i < numPlayers[gameId]; i++) {
                playerInfos[gameId].aggregatedPk = CurveBabyJubJub.pointAdd(
                    playerInfos[gameId].aggregatedPk[0],
                    playerInfos[gameId].aggregatedPk[1],
                    playerInfos[gameId].playerPk[2 * i],
                    playerInfos[gameId].playerPk[2 * i + 1]
                );
            }
            initDeck(gameId);
        }
    }

    // Returns the aggregated public key for all players.
    function queryAggregatedPk(
        uint256 gameId
    ) external view override returns (uint256[2] memory) {
        require(
            states[gameId] != State.Registration,
            "aggregated pk is not ready"
        );
        return playerInfos[gameId].aggregatedPk;
    }

    // Queries deck.
    function queryDeck(
        uint256 gameId
    ) external view override returns (Deck memory) {
        require(states[gameId] != State.Registration, "deck is not ready");
        return decks[gameId];
    }

    // Queries the `index`-th card from the deck.
    function queryCardFromDeck(
        uint256 index,
        uint256 gameId
    )
        external
        view
        override
        inDealingPhase(gameId)
        returns (uint256[4] memory card)
    {
        card[0] = decks[gameId].X0[index];
        card[1] = decks[gameId].X1[index];
        card[2] = decks[gameId].Selector[0];
        card[3] = decks[gameId].Selector[1];
    }

    // Queries the `index`-th card in deal.
    function queryCardInDeal(
        uint256 index,
        uint256 gameId
    )
        external
        view
        override
        inDealingPhase(gameId)
        returns (uint256[4] memory card)
    {
        card[0] = cardDeals[gameId].cards[index].X0;
        card[1] = cardDeals[gameId].cards[index].Y0;
        card[2] = cardDeals[gameId].cards[index].X1;
        card[3] = cardDeals[gameId].cards[index].Y1;
    }

    // Prepares public signal array for verifying card shuffling.
    function prepareShuffleData(
        uint256 nonce,
        uint256[5] memory shuffledX0,
        uint256[5] memory shuffledX1,
        uint256[2] memory selector,
        uint256 gameId
    ) public view returns (uint256[27] memory input) {
        input[0] = nonce;
        input[1] = playerInfos[gameId].aggregatedPk[0];
        input[2] = playerInfos[gameId].aggregatedPk[1];
        for (uint256 i = 0; i < 5; i++) {
            input[i + 3] = decks[gameId].X0[i];
            input[i + 8] = decks[gameId].X1[i];
            input[i + 13] = shuffledX0[i];
            input[i + 18] = shuffledX1[i];
        }
        input[23] = decks[gameId].Selector[0];
        input[24] = decks[gameId].Selector[1];
        input[25] = selector[0];
        input[26] = selector[1];
    }

    // Updates deck with the shuffled deck.
    function updateDeck(
        uint256[5] memory shuffledX0,
        uint256[5] memory shuffledX1,
        uint256[2] memory selector,
        uint256 gameId
    ) internal {
        for (uint256 i = 0; i < 5; i++) {
            decks[gameId].X0[i] = shuffledX0[i];
            decks[gameId].X1[i] = shuffledX1[i];
        }
        decks[gameId].Selector[0] = selector[0];
        decks[gameId].Selector[1] = selector[1];
    }

    // Shuffles the deck for `permanentAccount`.
    function shuffle(
        address permanentAccount,
        uint256[8] memory proof,
        uint256 nonce,
        uint256[5] memory shuffledX0,
        uint256[5] memory shuffledX1,
        uint256[2] memory selector,
        uint256 gameId
    ) external override onlyGameContract {
        require(states[gameId] == State.ShufflingDeck, "Not in shuffle phase");
        require(
            permanentAccount ==
                playerInfos[gameId].playerAddr[playerIndexes[gameId]],
            "Not your turn yet"
        );
        shuffleEncryptVerifier.verifyProof(
            [proof[0], proof[1]],
            [[proof[2], proof[3]], [proof[4], proof[5]]],
            [proof[6], proof[7]],
            prepareShuffleData(nonce, shuffledX0, shuffledX1, selector, gameId)
        );
        updateDeck(shuffledX0, shuffledX1, selector, gameId);
        playerIndexes[gameId] += 1;
        if (playerIndexes[gameId] == numPlayers[gameId]) {
            states[gameId] = State.DealingCard;
            playerIndexes[gameId] = 0;
        }
    }

    // Decompresses an elliptic curve point.
    function decompressEC(
        uint256 x,
        uint256 delta,
        uint256 selector
    ) internal pure returns (uint256) {
        require(
            delta <=
                10944121435919637611123202872628637544274182200208017171849102093287904247808,
            "Ill-formated delta"
        );
        require(
            CurveBabyJubJub.isOnCurve(x, delta),
            "Not on baby jubjub curve"
        );
        require((selector == 0) || (selector == 1), "Ill-formated selector");
        if (selector == 1) {
            return delta;
        } else {
            return CurveBabyJubJub.Q - delta;
        }
    }

    // Decompresses a card.
    function decompressCard(
        uint256 cardIdx,
        uint256[2] memory delta,
        uint256 gameId
    ) internal view returns (uint256[2] memory Y) {
        uint256 flag0 = (decks[gameId].Selector[0] & (1 << cardIdx)) >> cardIdx;
        uint256 flag1 = (decks[gameId].Selector[1] & (1 << cardIdx)) >> cardIdx;
        Y[0] = decompressEC(decks[gameId].X0[cardIdx], delta[0], flag0);
        Y[1] = decompressEC(decks[gameId].X1[cardIdx], delta[1], flag1);
    }

    // Deals the `cardIdx`-th card given the zk `proof` of validity and `out` for decrypted card from `curPlayerIdx`.
    //  `initDelta` is used when `curPlayerIdx` is the first one to decrypt `cardIdx`-th card due to the compressed
    //  representation of elliptic curve points.
    function deal(
        address permanentAccount,
        uint256 cardIdx,
        uint256 curPlayerIdx,
        uint256[8] memory proof,
        uint256[2] memory decryptedCard,
        uint256[2] memory initDelta,
        uint256 gameId
    ) external override inDealingPhase(gameId) {
        require(
            playerInfos[gameId].playerAddr[curPlayerIdx] == permanentAccount,
            "not recognized player"
        );
        require(
            (cardDeals[gameId].record[cardIdx] & (1 << curPlayerIdx)) == 0,
            "detected double dealing the same card"
        );
        if (cardDeals[gameId].record[cardIdx] == 0) {
            uint256[2] memory Y = decompressCard(cardIdx, initDelta, gameId);
            cardDeals[gameId].cards[cardIdx].X0 = decks[gameId].X0[cardIdx];
            cardDeals[gameId].cards[cardIdx].X1 = decks[gameId].X1[cardIdx];
            cardDeals[gameId].cards[cardIdx].Y0 = Y[0];
            cardDeals[gameId].cards[cardIdx].Y1 = Y[1];
        }
        decryptVerifier.verifyProof(
            [proof[0], proof[1]],
            [[proof[2], proof[3]], [proof[4], proof[5]]],
            [proof[6], proof[7]],
            [
                decryptedCard[0],
                decryptedCard[1],
                cardDeals[gameId].cards[cardIdx].X0,
                cardDeals[gameId].cards[cardIdx].Y0,
                cardDeals[gameId].cards[cardIdx].X1,
                cardDeals[gameId].cards[cardIdx].Y1,
                playerInfos[gameId].playerPk[2 * curPlayerIdx],
                playerInfos[gameId].playerPk[2 * curPlayerIdx + 1]
            ]
        );
        cardDeals[gameId].cards[cardIdx].X1 = decryptedCard[0];
        cardDeals[gameId].cards[cardIdx].Y1 = decryptedCard[1];
        cardDeals[gameId].record[cardIdx] |= (1 << curPlayerIdx);
    }

    // Searches the value of the `cardIndex`-th card in the `gameId`-th game.
    function search(
        uint256 cardIndex,
        uint256 gameId
    ) external view override returns (uint256) {
        require(
            cardDeals[gameId].record[cardIndex] ==
                (1 << numPlayers[gameId]) - 1,
            "Card has not been fully decrypted"
        );
        uint256 X1 = cardDeals[gameId].cards[cardIndex].X1;
        for (uint256 i = 0; i < 5; i++) {
            if (initialDeck.X1[i] == X1) {
                return i;
            }
        }
        return INVALID_CARD_INDEX;
    }

    function getInitialDeck() external view returns (Deck memory) {
        return initialDeck;
    }
}

library Pairing {
    error InvalidProof();

    // The prime q in the base field F_q for G1
    uint256 constant BASE_MODULUS =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // The prime moludus of the scalar field of G1.
    uint256 constant SCALAR_MODULUS =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    struct G1Point {
        uint256 X;
        uint256 Y;
    }

    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint256[2] X;
        uint256[2] Y;
    }

    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        return
            G2Point(
                [
                    11559732032986387107991004021392285783925812861821192530917403151452391805634,
                    10857046999023057135944570762232829481370756359578518086990519993285655852781
                ],
                [
                    4082367875863433681332203403145435568316851327593401208105741076214120093531,
                    8495653923123431417604973247489272438418190587263600148770280649306958101930
                ]
            );
    }

    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        if (p.X == 0 && p.Y == 0) return G1Point(0, 0);
        // Validate input or revert
        if (p.X >= BASE_MODULUS || p.Y >= BASE_MODULUS) revert InvalidProof();
        // We know p.Y > 0 and p.Y < BASE_MODULUS.
        return G1Point(p.X, BASE_MODULUS - p.Y);
    }

    /// @return r the sum of two points of G1
    function addition(
        G1Point memory p1,
        G1Point memory p2
    ) internal view returns (G1Point memory r) {
        // By EIP-196 all input is validated to be less than the BASE_MODULUS and form points
        // on the curve.
        uint256[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
        }
        if (!success) revert InvalidProof();
    }

    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(
        G1Point memory p,
        uint256 s
    ) internal view returns (G1Point memory r) {
        // By EIP-196 the values p.X and p.Y are verified to less than the BASE_MODULUS and
        // form a valid point on the curve. But the scalar is not verified, so we do that explicitelly.
        if (s >= SCALAR_MODULUS) revert InvalidProof();
        uint256[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
        }
        if (!success) revert InvalidProof();
    }

    /// Asserts the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should succeed
    function pairingCheck(
        G1Point[] memory p1,
        G2Point[] memory p2
    ) internal view {
        // By EIP-197 all input is verified to be less than the BASE_MODULUS and form elements in their
        // respective groups of the right order.
        if (p1.length != p2.length) revert InvalidProof();
        uint256 elements = p1.length;
        uint256 inputSize = elements * 6;
        uint256[] memory input = new uint256[](inputSize);
        for (uint256 i = 0; i < elements; i++) {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint256[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(
                sub(gas(), 2000),
                8,
                add(input, 0x20),
                mul(inputSize, 0x20),
                out,
                0x20
            )
        }
        if (!success || out[0] != 1) revert InvalidProof();
    }
}

// Library for addition on baby jubjub curve.
// Baby JubJub Curve: 168700x^2 + y^2 = 1 + 168696x^2y^2
// Borrowed with modification from https://github.com/yondonfu/sol-baby-jubjub/blob/master/contracts/CurveBabyJubJub.sol
library CurveBabyJubJub {
    uint256 public constant A = 168700;
    uint256 public constant D = 168696;
    uint256 public constant Q =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    // Adds 2 points on a twisted Edwards curve:
    // x3 = (x1y2 + y1x2) / (1 + dx1x2y1y2)
    // y3 = (y1y2 - ax1x2) / (1 - dx1x2y1y2)
    function pointAdd(
        uint256 _x1,
        uint256 _y1,
        uint256 _x2,
        uint256 _y2
    ) internal view returns (uint256[2] memory point) {
        if (_x1 == 0 && _y1 == 0) return [_x2, _y2];
        if (_x2 == 0 && _y1 == 0) return [_x1, _y1];
        uint256 x1x2 = mulmod(_x1, _x2, Q);
        uint256 y1y2 = mulmod(_y1, _y2, Q);
        uint256 dx1x2y1y2 = mulmod(D, mulmod(x1x2, y1y2, Q), Q);
        uint256 x3Num = addmod(mulmod(_x1, _y2, Q), mulmod(_y1, _x2, Q), Q);
        uint256 y3Num = submod(y1y2, mulmod(A, x1x2, Q), Q);
        point[0] = mulmod(x3Num, inverse(addmod(1, dx1x2y1y2, Q)), Q);
        point[1] = mulmod(y3Num, inverse(submod(1, dx1x2y1y2, Q)), Q);
    }

    // Performs scalar multiplication.
    // TODO: Use advanced cryptography optimizations to save gas.
    function pointMul(
        uint256 _x1,
        uint256 _y1,
        uint256 _d
    ) internal view returns (uint256[2] memory point) {
        uint256[2] memory tmp;
        uint256 remaining = _d;
        uint256 px = _x1;
        uint256 py = _y1;
        uint256 ax = 0;
        uint256 ay = 0;
        while (remaining != 0) {
            if ((remaining & 1) != 0) {
                tmp = pointAdd(ax, ay, px, py);
                ax = tmp[0];
                ay = tmp[1];
            }
            tmp = pointAdd(px, py, px, py);
            px = tmp[0];
            py = tmp[1];
            remaining = remaining / 2;
        }
        point[0] = ax;
        point[1] = ay;
    }

    // Checks if a point is on baby jubjub curve.
    function isOnCurve(uint256 _x, uint256 _y) internal pure returns (bool) {
        uint256 xSq = mulmod(_x, _x, Q);
        uint256 ySq = mulmod(_y, _y, Q);
        uint256 lhs = addmod(mulmod(A, xSq, Q), ySq, Q);
        uint256 rhs = addmod(1, mulmod(mulmod(D, xSq, Q), ySq, Q), Q);
        return submod(lhs, rhs, Q) == 0;
    }

    // Performs modular subtraction.
    function submod(
        uint256 _a,
        uint256 _b,
        uint256 _mod
    ) internal pure returns (uint256) {
        uint256 aNN = _a;
        if (_a <= _b) aNN += _mod;
        return addmod(aNN - _b, 0, _mod);
    }

    // Computes the inversion of a number.
    // We can use Euler's theorem instead of the extended Euclidean algorithm
    // Since m = Q and Q is prime we have: a^-1 = a^(m - 2) (mod m)
    // TODO: Try extended euclidean algorithm and see if we can save gas.
    function inverse(uint256 _a) internal view returns (uint256) {
        return expmod(_a, Q - 2, Q);
    }

    /**
     * @dev Helper function to call the bigModExp precompile
     */
    function expmod(
        uint256 _b,
        uint256 _e,
        uint256 _m
    ) internal view returns (uint256 o) {
        assembly {
            let memPtr := mload(0x40)
            mstore(memPtr, 0x20) // Length of base _b
            mstore(add(memPtr, 0x20), 0x20) // Length of exponent _e
            mstore(add(memPtr, 0x40), 0x20) // Length of modulus _m
            mstore(add(memPtr, 0x60), _b) // Base _b
            mstore(add(memPtr, 0x80), _e) // Exponent _e
            mstore(add(memPtr, 0xa0), _m) // Modulus _m

            // The bigModExp precompile is at 0x05
            let success := staticcall(gas(), 0x05, memPtr, 0xc0, memPtr, 0x20)
            switch success
            case 0 {
                revert(0x0, 0x0)
            }
            default {
                o := mload(memPtr)
            }
        }
    }
}