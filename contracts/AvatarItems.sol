// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AvatarItems is ERC1155, VRFConsumerBaseV2 {
    // ERRORS
    error AvatarItems_insufficientBalance();

    // EVENTS
    event packBought(address indexed _address, uint256 _requestId);
    event packOpened(
        address indexed _address,
        uint256 _requestId,
        uint256 _itemId
    );
    event itemAdded(ItemType _type, uint256 _itemId, string _name);
    event earnedReward(address indexed _address, uint256 _amount);

    // COINS
    uint256 public constant s_rewardCoins = 0;

    // ITEMS
    uint256 public s_itemCounter = 1;

    uint256 public s_packPrice;
    address private s_owner;

    // VRF
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;
    bytes32 s_keyHash;
    uint32 s_callbackGasLimit;
    uint16 constant s_requestConfirmations = 3;
    uint32 constant s_numWords = 2;

    // ITEMTYPE for targeting body part
    enum ItemType {
        avatarSkin, //12%
        avatarUpperBody, //22%
        avatarLowerBody, //22%
        avatarShoes, //22%
        avatarAccessories //22%
    }

    // DESCRIPTION OF TOKEN IDS
    struct ItemDescription {
        string name;
        uint256 itemSupply;
    }

    // Mapping item type to all token ids that are made for the type
    mapping(ItemType => uint256[]) public ItemTypes;

    // Mapping token id to their description
    mapping(uint256 => ItemDescription) public ItemDescriptions;

    // Mapping to store authorized contracts(games and content contracts)
    mapping(address => bool) public AuthorizedContracts;

    // Mapping to store the discounts for the packs
    mapping(address => uint256) public Discounts;

    // OWNER MODIFIER
    modifier onlyOwner() {
        require(
            msg.sender == s_owner,
            "The address doesnt have permission to call this function"
        );
        _;
    }

    // CONTRACT AUTHORIZATION MODIFIER TO CHECK IF THE EXTERNAL CONTRACTS CAN CALL OUR FUNCTION
    modifier isAuthorized() {
        require(
            AuthorizedContracts[msg.sender] == true,
            "The address is not part of authorized contracts"
        );
        _;
    }

    // NEED TO ADD THE IPFS TOKEN URI
    constructor(
        uint64 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint256 _packPrice
    )
        ERC1155("https://ipfs.io/ipfs/HASH_HERE/{id}.json")
        VRFConsumerBaseV2(vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
        s_keyHash = keyHash;
        s_callbackGasLimit = callbackGasLimit;
        s_packPrice = _packPrice;
    }

    // DOES THE ITEM EXIST
    function doesItemExist(string memory itemName) public view returns (bool) {
        bool result = false;
        for (uint256 i = 0; i < s_itemCounter; i++) {
            if (
                keccak256(bytes(ItemDescriptions[i + 1].name)) ==
                keccak256(bytes(itemName))
            ) {
                result = true;
                break;
            }
        }
        return result;
    }

    // ADD NEW ITEM
    function addAvatarItem(
        ItemType _type,
        string memory newName,
        uint256 itemSupply
    ) public onlyOwner {
        require(doesItemExist(newName) == false, "This item already exists");
        require(itemSupply > 0, "Item must have item Supply");
        ItemDescriptions[s_itemCounter] = ItemDescription(newName, itemSupply);
        ItemTypes[_type].push(s_itemCounter);
        s_itemCounter++;

        emit itemAdded(_type, s_itemCounter, newName);
    }

    // ADD SUPPLY OF THE ITEM(y/n)
    function addItemSupply(
        uint256 itemId,
        uint256 additionalSupply
    ) public onlyOwner {
        require(additionalSupply > 0, "Item must have item Supply");
        ItemDescriptions[itemId].itemSupply += additionalSupply;
    }

    // CALL THIS FUNCTION TO BUY PACKS WITH REWARDCOINS
    // To reduce the cost of calling vrf each pack, we could buy multiple at once
    function buyPack(address _address) external {
        require(
            waitingForResponse[_address] == false,
            "The address is waiting for response"
        );
        if (
            balanceOf(_address, 0) <
            (s_packPrice * (100 - Discounts[_address])) / 100
        ) {
            revert AvatarItems_insufficientBalance();
        }
        super._burn(
            _address,
            0,
            (s_packPrice * (100 - Discounts[_address])) / 100 // To calculate discounts
        );
        uint256 requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            s_requestConfirmations,
            s_callbackGasLimit,
            s_numWords
        );
        getRequestAddress[requestId] = _address;
        waitingForResponse[_address] = true;

        emit packBought(_address, requestId);
    }

    // GET THE RANDOM NUMBER BACK
    mapping(uint256 => address) public getRequestAddress;
    mapping(address => bool) public waitingForResponse;

    // GET ITEM BACK FROM BUYING A PACK (VRF RANDOM NUMBER)
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // RANDOM NUMBER FROM 1-100
        uint256 result = ((randomWords[0] % 99) + 1);

        // TO GET ITEM TYPE
        uint256 currentChance = 0;
        ItemType resulttype;
        uint8[5] memory chances = getChanceArray();
        for (uint256 i = 0; i < chances.length; i++) {
            if (result > currentChance && result < chances[i]) {
                resulttype = ItemType(i);
                break;
            }
            currentChance = chances[i];
        }

        // GET THE ACTUAL ITEM ID
        // First the supply of all items of the resulted item type is sumed up.
        uint256 totalItemTypeSupply = 0;
        for (uint256 i = 0; i < ItemTypes[resulttype].length; i++) {
            totalItemTypeSupply += ItemDescriptions[ItemTypes[resulttype][i]]
                .itemSupply; // GET ITEM SUPPLY OF EACH ELEMENT THAT IS NESTED IN CERTAIN ITEM TYPE
        }

        // Getting the random words from VRF and dividing it by total item supply
        uint256 result2 = ((randomWords[0] % totalItemTypeSupply) + 1);

        // We loop through an array of item of a certain item type to get the winning item.
        // The same as for the item type but the chance array is not provided, because it is all variable based on the token supply
        uint256 currentItem = 0;
        uint256 itemReward;
        for (uint256 i = 0; i < ItemTypes[resulttype].length; i++) {
            if (
                result2 > currentItem &&
                result2 < ItemDescriptions[ItemTypes[resulttype][i]].itemSupply
            ) {
                itemReward = ItemTypes[resulttype][i];
                break;
            }
            currentItem = ItemDescriptions[ItemTypes[resulttype][i]].itemSupply;
        }

        // MINT THE ITEM ID
        super._mint(getRequestAddress[requestId], itemReward, 1, "");
        waitingForResponse[getRequestAddress[requestId]] = false;

        emit packOpened(getRequestAddress[requestId], requestId, itemReward);
    }

    // CHANCE FOR DIFFERENT ITEM TYPES
    function getChanceArray() public pure returns (uint8[5] memory) {
        return [12, 34, 56, 78, 100];
    }

    // CALL THIS FUNCTION TO MINT NEW TOKENS
    // Figure out how we are going to distribute the reward tokens, if we are going to have distribution in this contract
    function earnRewards(
        address _address,
        uint256 amount
    ) external isAuthorized {
        super._mint(_address, 0, amount, "");
        emit earnedReward(_address, amount);
    }

    // CHANGE PACK PRICE, if random events occur to give our players discounts
    // If we want to give certain players discount we can do mappings of price for each player
    // Could include upkeep(time) if we want to
    function setPackPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Pack price can't be 0");
        s_packPrice = newPrice;
    }

    // AUTHORIZES THE CONTRACT TO CALL OUR FUNCTIONS
    // If needed can add that only a contract can be authorized, no addresses, for transparency reasons
    function authorizeContract(address _address) external onlyOwner {
        AuthorizedContracts[_address] = true;
    }

    // TOKEN URI
    function uri(
        uint256 _tokenId
    ) public pure override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "https://ipfs.io/HASH_HERE/",
                    Strings.toString(_tokenId),
                    ".json"
                )
            );
    }

    // URI for entire contract
    function contractURI() public pure returns (string memory) {
        return "https://ipfs.io/ipfs/HASH_HERE/collection.json";
    }

    // VIEW ITEM DESCRIPTION
    function viewItemDescription(
        uint256 itemId
    ) public view returns (ItemDescription memory) {
        return ItemDescriptions[itemId];
    }

    //GET A RANDOM POWER UP
    // Could be called if the user reaches a certain milestone, could also make it a pack
    function getPowerUp() external isAuthorized {}
}
