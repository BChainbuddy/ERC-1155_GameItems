// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract Nfts is ERC1155, VRFConsumerBaseV2 {
    // ERRORS
    // EVENTS

    // COINS
    uint256 public constant rewardCoins = 0;

    // NFTTYPE for targeting body part
    enum NFTtype {
        avatarSkin, //12%
        avatarUpperBody, //22%
        avatarLowerBody, //22%
        avatarShoes, //22%
        avatarAccessories //22%
    }

    // Mapping nft type to all token ids that are made for the type
    mapping(NFTtype => uint256[]) public NFTtypes;

    // Mapping token id to their description
    mapping(uint256 => NftDescription) public NFTDescriptions;

    struct NftDescription {
        string name;
        // Chance to get it
    }

    uint256[] public avatarNfts; //1,2,3,...

    // ADD NEW NFT
    function addNewNFTOption(
        NFTtype _type,
        uint256 newId,
        string memory newName
    ) public onlyOwner {
        require(
            doesNFTOptionExist(newId, newName) == false,
            "This nft option already exists"
        );
        avatarNfts.push(newId);
        NFTDescriptions[newId] = NftDescription(newName);
        NFTtypes[_type].push(newId);
    }

    // DOES THE NFT EXIST, string or the nftId
    function doesNFTOptionExist(
        uint256 nftId,
        string memory nftName
    ) public view returns (bool) {
        bool result = false;
        for (uint256 i = 0; i < avatarNfts.length; i++) {
            if (avatarNfts[i] == nftId) {
                result = true;
                break;
            } else if (NFTDescriptions[avatarNfts[i]].name == nftName) {
                result = true;
                break;
            }
        }
        return result;
    }

    // // POWER UPS
    // uint256 public constant doubleMultiplier = 6
    // uint256 public constant tripleMultiplier = 7

    uint256 public packPrice;
    address private owner;

    // VRF
    uint64 s_subscriptionId;
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator;
    bytes32 s_keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint32 numWords;

    // MAPPING TO STORE AUTHORIZED CONTRACTS(GAMES AND CONTENT)
    mapping(address => bool) public authorizedContracts;

    // NEED TO ADD THE IPFS TOKEN URI
    constructor(
        uint64 subscriptionId
    ) ERC1155(uri) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    // OWNER MODIFIER
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "The address doesnt have permission to call this function"
        );
        _;
    }

    // CONTRACT AUTHORIZATION MODIFIER TO CHECK IF THE EXTERNAL CONTRACTS CAN CALL OUR FUNCTION
    modifier isAuthorized() {
        require(
            true == authorizedContracts[msg.sender],
            "The address is not part of authorized contracts"
        );
        _;
    }

    // CALL THIS FUNCTION TO BUY PACKS WITH REWARDCOINS
    // To reduce the cost of calling vrf each pack, we could buy multiple at once
    function buyPack(address _address) external {
        super._burn(_address, 0, packPrice);
        uint256 requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        getRequestAddress[requestId] = _address;
    }

    mapping(uint256 => address) public getRequestAddress;
    mapping(address => bool) public waitingForResponse;

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // GET NFT TYPE, uint 1 to 100, then converted to a NFT TYPE
        uint256 result = ((randomWords[0] % 99) + 1);

        // GET NFT ID, uint256 of the nft option
        // uint256 result2 = NFTtypes[(randomWords[1] % NFTtypes[_type].length)];

        // super._mint(getRequestAddress[requestId], result2, 1, "");
    }

    // CHANCE FOR DIFFERENT TYPES
    function getChanceArray() public view returns (uint8[5] memory) {
        return [12, 34, 56, 78, 100];
    }

    //GET A RANDOM POWER UP
    // Could be called if the user reaches a certain milestone, could also make it a pack
    function getPowerUp() external isAuthorized {}

    // CALL THIS FUNCTION TO MINT NEW TOKENS
    // Figure out how we are going to distribute the reward tokens, if we are going to have distribution in this contract
    function earnRewards(uint256 amount) external {
        super._mint(msg.sender, 0, amount, "");
    }

    // CHANGE PACK PRICE, if random events occur to give our players discounts
    // If we want to give certain players discount we can do mappings of price for each player
    // Could include upkeep(time) if we want to
    function setPackPrice(uint256 newPrice) external onlyOwner {
        packPrice = newPrice;
    }

    // AUTHORIZES THE CONTRACT TO CALL OUR FUNCTIONS
    // If needed can add that only a contract can be authorized, no addresses, for transparency reasons
    function authorizeContract(address _address) external onlyOwner {
        authorizedContracts[_address] = true;
    }

    // GIVE DISCOUNT TO A CERTAIN PLAYER IF THEY UNLOCK CERTAIN ACHIVEMENTS
    // mapping of address and discount
    // function to change the discount of a player
}
