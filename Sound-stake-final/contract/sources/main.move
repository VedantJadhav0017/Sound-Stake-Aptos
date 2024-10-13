module MyModule::SongFractionalizedsdk {
    use aptos_framework::signer;
    use aptos_framework::timestamp;
    use aptos_framework::coin; // Use coin module for payment handling
    use aptos_framework::aptos_coin; // Import aptos_coin module
    use std::vector;

    // Struct representing a song listed for fractional sale.
    struct Song has store, key {
        title: vector<u8>,            
        artist_name: vector<u8>,       
        artist_address: address,       
        release_time: u64,             
        fraction_price: u64,           
        total_fractions: u64,          
        is_released: bool,                          
        fractions_sold: u64,           
        fraction_holders: vector<address>,  
    }

    struct SongList has store, key {
        songs: vector<Song>,           
        song_counter: u64,             
    }

    const E_CONTRACT_OWNER: address = @0x01fd6496190b519d90111533438fd50384cf825ce60a596579b0359ea3996201;

    /// Initialize the SongList storage on-chain
    public entry fun init_song_list(owner: &signer) {
        move_to(owner, SongList {
            songs: vector::empty<Song>(),
            song_counter: 0,
        });
    }

    /// Function to list a new song for fractional sale
    public entry fun list_song(
        owner: &signer,
        title: vector<u8>, 
        artist_name: vector<u8>, 
        release_time: u64, 
        fraction_price: u64, 
        total_fractions: u64
    ) acquires SongList {
        // Ensure release time is in the future
        assert!(release_time > timestamp::now_seconds(), 1);

        let song_list = borrow_global_mut<SongList>(signer::address_of(owner));
        song_list.song_counter = song_list.song_counter + 1;

        let song = Song {
            title,
            artist_name,
            artist_address: signer::address_of(owner),
            release_time,
            fraction_price,
            total_fractions,
            is_released: false,
            fractions_sold: 0,
            fraction_holders: vector::empty<address>(),
        };

        vector::push_back(&mut song_list.songs, song);
    }

    /// Function to check if a song should be unlisted and handle the unlisting
    public entry fun check_and_unlist(song_id: u64) acquires SongList {
        let song_list = borrow_global_mut<SongList>(E_CONTRACT_OWNER);
        let total_songs = vector::length(&song_list.songs);

        assert!(song_id < total_songs, 4); // Ensure song_id is within bounds

        let song_ref = vector::borrow_mut(&mut song_list.songs, song_id);
        let current_time = timestamp::now_seconds();

        if (current_time >= song_ref.release_time && !song_ref.is_released) {
            song_ref.is_released = true;
        }
    }

    /// Function to buy fractions of a song
    public entry fun buy_fractions(
        buyer: &signer, 
        song_id: u64, 
        amount: u64
    ) acquires SongList {
        // Ensure the song is still listed
        check_and_unlist(song_id);

        let song_list = borrow_global_mut<SongList>(E_CONTRACT_OWNER); // Use global owner of contract
        let total_songs = vector::length(&song_list.songs);

        assert!(song_id < total_songs, 4); // Ensure song_id is within bounds

        let song_ref = vector::borrow_mut(&mut song_list.songs, song_id);

        // Ensure the song is released for sale and there are enough unsold fractions
        assert!(song_ref.is_released, 5); // Ensure the song is released for sale
        assert!(song_ref.total_fractions - song_ref.fractions_sold >= amount, 3);

        // Calculate the total cost
        let total_cost = song_ref.fraction_price * amount;

        // Transfer the payment from the buyer to the artist
        coin::transfer<aptos_coin::AptosCoin>(buyer, song_ref.artist_address, total_cost);

        // Update the song's sold fractions and add the buyer to fraction holders
        song_ref.fractions_sold = song_ref.fractions_sold + amount;
        vector::push_back(&mut song_ref.fraction_holders, signer::address_of(buyer));
    }

    /// Function to get all fraction holders for a specific song
    public fun get_fraction_holders(song_id: u64): vector<address> acquires SongList {
        let song_list = borrow_global<SongList>(E_CONTRACT_OWNER);
        let total_songs = vector::length(&song_list.songs);

        assert!(song_id < total_songs, 4); // Ensure song_id is within bounds

        vector::borrow(&song_list.songs, song_id).fraction_holders
    }

    /// New function to get the current timestamp
    public fun get_current_timestamp(): u64 {
        timestamp::now_seconds()
    }
}