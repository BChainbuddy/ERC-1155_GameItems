// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract Profiles {


    struct Profile {
        address owner;
        string username;
        string avatar;
        string banner;
    }

    struct FriendRequest {
        address from;
        address to;
        uint256 sentAt;
        bool accepted;
        bool created;
    }

    mapping(address => Profile) public userProfiles;
    mapping(address => mapping(address => FriendRequest)) public friendRequests;
    mapping(address => address[]) public userFriendsRequests;
    mapping(address => uint256) public numberFriendsRequests;

    function register(string memory _username) public {
        require(userProfiles[msg.sender].owner != msg.sender, "The user already has an account");
        userProfiles[msg.sender] = Profile(msg.sender, _username, "default", "default");
    }

    function getProfile() public view returns(Profile memory _userProfile) {
        require(userProfiles[msg.sender].owner == msg.sender, "You don't have an account");
        _userProfile = userProfiles[msg.sender];
    }

    function sendFriendrequest(address _to) public {
        require(userProfiles[msg.sender].owner == msg.sender, "You don't have an account");
        require(!friendRequests[msg.sender][_to].created, "You have already sent a friend request to this user");
        require(!friendRequests[_to][msg.sender].created, "The user has already sent you a friend request");
        friendRequests[msg.sender][_to] = FriendRequest(msg.sender, _to, block.timestamp, false, true);
        friendRequests[_to][msg.sender] = FriendRequest(_to, msg.sender, block.timestamp, false, true);
        numberFriendsRequests[msg.sender]++;
        numberFriendsRequests[_to]++;
    }

    function getFriendRequests() public view returns(FriendRequest[] memory _friendRequests) {
        require(userProfiles[msg.sender].owner == msg.sender, "You don't have an account");
        require(numberFriendsRequests[msg.sender] > 0, "You don't have any friends requests");

        for(uint256 i = 0; i < numberFriendsRequests[msg.sender]; i++) {
            address current = userFriendsRequests[msg.sender][i];
            _friendRequests[i] = friendRequests[msg.sender][current];
        }
    }

    function acceptFriendRequest(address _from) public {
        require(userProfiles[msg.sender].owner == msg.sender, "You don't have an account");
        require(!friendRequests[msg.sender][_from].created && !friendRequests[_from][msg.sender].created, "This friend request doesn't exist");

        friendRequests[msg.sender][_from].accepted = true;
        friendRequests[_from][msg.sender].accepted = true;
        numberFriendsRequests[msg.sender]--;
        numberFriendsRequests[_from]--;
    }
}