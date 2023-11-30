// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// ERC1155 Token Standard - Semi-Fungible Token Standard
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

// Chainlink's VRF (Verifiable Random Function) integration
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

// Utility library for string manipulation
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title AvatarItems: ERC1155-based Tokens for Avatar Customization
 * @dev A contract allowing the purchase and opening of avatar customization packs with random items,
 * powered by Chainlink's VRF for randomness.
 */
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
    uint64 private immutable s_subscriptionId;
    bytes32 private immutable s_keyHash;
    uint32 private immutable s_callbackGasLimit;
    uint16 constant s_requestConfirmations = 3;
    uint32 constant s_numWords = 2;

    // ITEMTYPE for targeting body part
    enum ItemType {
        avatarSkin, //10%
        avatarUpperBody, //20%
        avatarLowerBody, //20%
        avatarShoes, //18%
        avatarAccessories, //12%
        banner //20%
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
        uint256 packPrice
    )
        ERC1155("https://ipfs.io/ipfs/HASH_HERE/{id}.json")
        VRFConsumerBaseV2(vrfCoordinator)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
        s_keyHash = keyHash;
        s_callbackGasLimit = callbackGasLimit;
        s_packPrice = packPrice;
    }

    /**
     * @dev Checks if an item with a given name already exists.
     * @param itemName The name of the item to check.
     * @return bool indicating whether the item exists or not.
     */
    function doesItemExist(string memory itemName) public view returns (bool) {
        bool result = false;
        for (uint256 i = 1; i <= s_itemCounter; i++) {
            if (
                keccak256(bytes(ItemDescriptions[i].name)) ==
                keccak256(bytes(itemName))
            ) {
                result = true;
                break;
            }
        }
        return result;
    }

    /**
     * @dev Adds a new avatar item to the contract.
     * @param _type The type of the item (e.g., avatarSkin, avatarUpperBody).
     * @param newName The name of the new item to be added.
     * @param itemSupply The initial supply of the item.
     */
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

    /**
     * @dev Increases the supply of a specific avatar item.
     * @param itemId The ID of the item to increase the supply for.
     * @param additionalSupply The amount by which to increase the supply.
     */
    function addItemSupply(
        uint256 itemId,
        uint256 additionalSupply
    ) public onlyOwner {
        require(additionalSupply > 0, "Item must have item Supply");
        ItemDescriptions[itemId].itemSupply += additionalSupply;
    }

    /**
     * @dev Allows purchasing avatar item packs with reward coins.
     * @param _address The address making the purchase.
     * @return requestId The ID of the request made to Chainlink's VRF.
     */
    function buyPack(address _address) public returns (uint256 requestId) {
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
        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            s_requestConfirmations,
            s_callbackGasLimit,
            s_numWords
        );
        getRequestAddress[requestId] = _address;
        waitingForResponse[_address] = true;

        emit packBought(_address, requestId);
        return requestId;
    }

    // GET THE RANDOM NUMBER BACK
    mapping(uint256 => address) public getRequestAddress;
    mapping(address => bool) public waitingForResponse;

    /**
     * @dev Handles the randomization and distribution of items upon pack opening.
     * @param requestId The ID of the request made to Chainlink's VRF.
     * @param randomWords Array containing random numbers generated by Chainlink's VRF.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // RANDOM NUMBER FROM 1-100
        uint256 result = ((randomWords[0] % 99) + 1);

        // TO GET ITEM TYPE
        uint256 currentChance = 0;
        ItemType resulttype;
        uint8[6] memory chances = getChanceArray();
        for (uint256 i = 0; i < chances.length; i++) {
            if (result > currentChance && result < chances[i]) {
                resulttype = ItemType(i);
                break;
            }
            currentChance = chances[i];
        }

        // GET THE ACTUAL ITEM ID
        // First the supply of all items of the resulted item type is sumed up.
        uint256 totalItemTypeSupply;
        for (uint256 i = 0; i < ItemTypes[resulttype].length; i++) {
            totalItemTypeSupply += ItemDescriptions[ItemTypes[resulttype][i]]
                .itemSupply; // GET ITEM SUPPLY OF EACH ELEMENT THAT IS NESTED IN CERTAIN ITEM TYPE
        }

        // Getting the random words from VRF and dividing it by total item supply
        uint256 result2 = ((randomWords[1] % totalItemTypeSupply) + 1);

        // We loop through an array of item of a certain item type to get the winning item.
        // The same as for the item type but the chance array is not provided, because it is all variable based on the token supply
        uint256 currentItem = 0;
        uint256 itemReward;
        for (uint256 i = 0; i < ItemTypes[resulttype].length; i++) {
            if (ItemDescriptions[ItemTypes[resulttype][i]].itemSupply == 0) {
                continue;
            } else if (
                result2 > currentItem &&
                result2 <=
                ItemDescriptions[ItemTypes[resulttype][i]].itemSupply +
                    currentItem
            ) {
                itemReward = ItemTypes[resulttype][i];
                break;
            }
            currentItem += ItemDescriptions[ItemTypes[resulttype][i]]
                .itemSupply;
        }

        // MINT THE ITEM ID
        super._mint(getRequestAddress[requestId], itemReward, 1, "");
        waitingForResponse[getRequestAddress[requestId]] = false;

        emit packOpened(getRequestAddress[requestId], requestId, itemReward);
    }

    /**
     * @dev Retrieves the chance array for different item types.
     * @return uint8 array representing the chances for different item types.
     */
    function getChanceArray() public pure returns (uint8[6] memory) {
        return [10, 30, 50, 68, 80, 100];
    }

    /**
     * @dev Mints rewards to specific addresses.
     * @param _address The address receiving the rewards.
     * @param amount The amount of rewards to mint.
     */
    function earnRewards(
        address _address,
        uint256 amount
    ) external isAuthorized {
        super._mint(_address, 0, amount * timeLock(_address), "");
        emit earnedReward(_address, amount * timeLock(_address));
    }

    /**
     * @dev Changes the price of avatar item packs.
     * @param newPrice The new price set for the avatar item packs.
     */
    function setPackPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Pack price can't be 0");
        s_packPrice = newPrice;
    }

    /**
     * @dev Authorizes an external contract to interact with this contract.
     * @param _address The address of the external contract to authorize.
     */
    function authorizeContract(address _address) external onlyOwner {
        AuthorizedContracts[_address] = true;
    }

    /**
     * @dev Retrieves the URI for a specific token ID.
     * @param _tokenId The ID of the token to retrieve the URI for.
     * @return string representing the URI of the token.
     */
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

    /**
     * @dev Retrieves the contract URI.
     * @return string representing the URI of the entire contract.
     */
    function contractURI() public pure returns (string memory) {
        return "https://ipfs.io/ipfs/HASH_HERE/collection.json";
    }

    /**
     * @dev Retrieves the description of a specific item.
     * @param itemId The ID of the item to retrieve the description for.
     * @return ItemDescription struct containing the item's details.
     */
    function viewItemDescription(
        uint256 itemId
    ) public view returns (ItemDescription memory) {
        return ItemDescriptions[itemId];
    }

    ////////////////////// POWERUPS

    event powerUpMinted(address indexed _address, uint256 powerUpId);

    // ALL POWERUPS
    mapping(uint256 => powerUp) public powerUps;

    // MAPPING FOR CURRENT POWERUP
    mapping(address => powerUpActivated) public ActivationCheck;

    // struct for Power Up
    struct powerUp {
        string name;
        uint256 multiplier;
        uint256 duration;
    }

    // struct for Activated Power Up, so we can calculate the duration and timestamp, for gas efficiency can change it into uint256
    struct powerUpActivated {
        uint256 timestamp;
        uint256 duration;
        uint256 multiplier;
    }

    /**
     * @dev Adds a new power-up to the contract.
     * @param name The name of the power-up.
     * @param multiplier The multiplier effect of the power-up.
     * @param duration The duration of the power-up's effect.
     */
    function addPowerUp(
        string memory name,
        uint256 multiplier,
        uint256 duration
    ) external onlyOwner {
        powerUps[s_itemCounter] = powerUp(name, multiplier, duration);
        s_itemCounter++;
    }

    /**
     * @dev Checks the duration of an activated power-up.
     * @param _address The address of the account holding the power-up.
     * @return uint256 indicating the remaining duration or 1 if not activated.
     */
    function timeLock(address _address) public view returns (uint256) {
        if (
            block.timestamp >
            ActivationCheck[_address].timestamp +
                ActivationCheck[_address].duration
        ) {
            return 1;
        } else {
            return ActivationCheck[_address].multiplier;
        }
    }

    /**
     * @dev Activates a power-up and burns it from the user's account.
     * @param powerupId The ID of the power-up to activate.
     */
    function activatePowerUp(uint256 powerupId) external {
        require(timeLock(msg.sender) == 1, "The last powerup is still on!");
        super._burn(msg.sender, powerupId, 1);
        ActivationCheck[msg.sender] = powerUpActivated(
            block.timestamp,
            powerUps[powerupId].duration,
            powerUps[powerupId].multiplier
        );
    }

    /**
     * @dev Mints a power-up to a user's account.
     * @param _address The address receiving the power-up.
     * @param powerUpId The ID of the power-up to mint.
     * @param amount The amount of the power-up to mint.
     */
    function powerUpMint(
        address _address,
        uint256 powerUpId,
        uint256 amount
    ) external {
        require(
            powerUps[powerUpId].duration > 0,
            "This powerUp is not available"
        );
        super._mint(_address, powerUpId, amount, "");
        emit powerUpMinted(_address, powerUpId);
    }
}
