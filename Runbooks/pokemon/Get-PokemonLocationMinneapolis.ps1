$StartingLat = 45.2088139415905 -as [double]
$StartingLong = -93.4882834291458 -as [double]
$Distance = .008 -as [double]

$a = '{"121":"Starmie","31":"Nidoqueen","117":"Seadra","59":"Arcanine","5":"Charmeleon","53":"Persian","47":"Parasect","146":"Moltres","78":"Rapidash","89":"Muk","108":"Lickitung","39":"Jigglypuff","132":"Ditto","51":"Dugtrio","144":"Articuno","62":"Poliwrath","43":"Oddish","45":"Vileplume","14":"Kakuna","103":"Exeggutor","87":"Dewgong","49":"Venomoth","100":"Voltorb","116":"Horsea","68":"Machamp","81":"Magnemite","125":"Electabuzz","113":"Chansey","141":"Kabutops","75":"Graveler","94":"Gengar","21":"Spearow","85":"Dodrio","114":"Tangela","80":"Slowbro","52":"Meowth","30":"Nidorina","145":"Zapdos","32":"Nidoran♂","109":"Koffing","73":"Tentacruel","67":"Machoke","133":"Eevee","8":"Wartortle","29":"Nidoran♀","2":"Ivysaur","33":"Nidorino","3":"Venusaur","84":"Doduo","107":"Hitmonchan","58":"Growlithe","37":"Vulpix","139":"Omastar","112":"Rhydon","48":"Venonat","42":"Golbat","130":"Gyarados","65":"Alakazam","35":"Clefairy","110":"Weezing","60":"Poliwag","115":"Kangaskhan","34":"Nidoking","126":"Magmar","104":"Cubone","28":"Sandslash","76":"Golem","101":"Electrode","13":"Weedle","50":"Diglett","106":"Hitmonlee","19":"Rattata","9":"Blastoise","134":"Vaporeon","57":"Primeape","142":"Aerodactyl","64":"Kadabra","12":"Butterfree","119":"Seaking","99":"Kingler","129":"Magikarp","127":"Pinsir","24":"Arbok","1":"Bulbasaur","122":"Mr. Mime","66":"Machop","82":"Magneton","41":"Zubat","23":"Ekans","111":"Rhyhorn","123":"Scyther","91":"Cloyster","79":"Slowpoke","72":"Tentacool","143":"Snorlax","118":"Goldeen","18":"Pidgeot","90":"Shellder","135":"Jolteon","56":"Mankey","150":"Mewtwo","83":"Farfetch\u0027d","92":"Gastly","71":"Victreebel","11":"Metapod","105":"Marowak","16":"Pidgey","77":"Ponyta","93":"Haunter","25":"Pikachu","137":"Porygon","38":"Ninetales","54":"Psyduck","6":"Charizard","20":"Raticate","40":"Wigglytuff","149":"Dragonite","27":"Sandshrew","96":"Drowzee","128":"Tauros","97":"Hypno","4":"Charmander","46":"Paras","120":"Staryu","74":"Geodude","147":"Dratini","98":"Krabby","70":"Weepinbell","17":"Pidgeotto","69":"Bellsprout","88":"Grimer","102":"Exeggcute","136":"Flareon","55":"Golduck","131":"Lapras","22":"Fearow","44":"Gloom","151":"Mew","61":"Poliwhirl","15":"Beedrill","140":"Kabuto","86":"Seel","26":"Raichu","138":"Omanyte","36":"Clefable","10":"Caterpie","7":"Squirtle","63":"Abra","124":"Jynx","148":"Dragonair","95":"Onix"}'
$pokemonHT = ConvertFrom-Json $a

$ScanTable = @{}

$DocDBContext = New-DocDBContext -Uri 'https://scopokemongo.documents.azure.com' -Key 'K5cIgBG0rnlFePhIlh5IB8aK5D4bNfAPXXFqiVmHXdKh0OGzOTBhN1KNIJH45zgn82mpMpUFdqQVZ7dgS1qoDg=='

for($i = 0 ; $i -gt -70 ; $i-=1)
{
    $StartTime = (Get-Date -Format 'MMddyyyyhhmmsstt')
    $Page = new-object -typename system.collections.arraylist
    for($j = 0 ; $j -lt 75; $j++)
    {
        $ScanningLat = $StartingLat + ($Distance * $i)
        $ScanningLong = $StartingLong + ($Distance * $j)
        
        #$ScanPlace = Invoke-WebRequest -Uri "http://dev.virtualearth.net/REST/v1/Locations/$($ScanningLat),$($ScanningLong)?&o=xml&key=Amz0WOZj3_pVHerw3Xnlci4eW5v-ckDAjjW66crtvoREaBbkA93CFXlJnaWt2zaF" -UseBasicParsing
        #if($ScanPlace.Content -as [string] -match '<Name>(.+?)(?=</Name>)') { $ScanAddress = $Matches[1] }
        #else { $ScanAddress = "$ScanningLat,$ScanningLog" }

        #$ScanPlaceNeighborhoodRequest = Invoke-WebRequest -Uri "http://dev.virtualearth.net/REST/v1/Locations/$($ScanningLat),$($ScanningLong)?includeEntityTypes=Neighborhood&o=xml&key=Amz0WOZj3_pVHerw3Xnlci4eW5v-ckDAjjW66crtvoREaBbkA93CFXlJnaWt2zaF" -UseBasicParsing
        #if($ScanPlaceNeighborhoodRequest.Content -as [string] -match '<Name>(.+?)(?=</Name>)') { $ScanNeighborhood = $Matches[1] }
        #else { $ScanNeighborhood = $ScanAddress }

        $ScanTime = (Get-Date -Format 'MM-dd-yyyy hh:mm:ss tt')
        $ScanTimeRounded = ([datetime]$ScanTime).Date + (new-object system.timespan ([math]::Round(([datetime]$ScanTime).TimeofDay.TotalHours)),0,0)
        $Request = invoke-webrequest -uri "https://pokevision.com/map/data/$ScanningLat/$ScanningLong" -UseBasicParsing
        $Pokemon = ($Request.Content | ConvertFrom-JSON).Pokemon

        Foreach($_Pokemon in $Pokemon)
        {
            if(-not $ScanTable.ContainsKey($_Pokemon.id))
            {
                #$PokemonPlaceRequest = Invoke-WebRequest -Uri "http://dev.virtualearth.net/REST/v1/Locations/$($_Pokemon.Latitude),$($_Pokemon.longitude)?o=xml&key=Amz0WOZj3_pVHerw3Xnlci4eW5v-ckDAjjW66crtvoREaBbkA93CFXlJnaWt2zaF" -UseBasicParsing
                #if($PokemonPlaceRequest.Content -as [string] -match '<Name>(.+?)(?=</Name>)') { $PokemonPlace = $Matches[1] }
                #else { $PokemonPlace = "$($_Pokemon.Latitude),$($_Pokemon.longitude)" }

                #$PokemonNeighborhoodRequest = Invoke-WebRequest -Uri "http://dev.virtualearth.net/REST/v1/Locations/$($_Pokemon.latitude),$($_Pokemon.longitude)?includeEntityTypes=Neighborhood&o=xml&key=Amz0WOZj3_pVHerw3Xnlci4eW5v-ckDAjjW66crtvoREaBbkA93CFXlJnaWt2zaF" -UseBasicParsing
                #if($PokemonNeighborhoodRequest.Content -as [string] -match '<Name>(.+?)(?=</Name>)') { $PokemonNeighborhood = $Matches[1] }
                #else { $PokemonNeighborhood = "$PokemonPlace" }

                $_Pokemon | Add-Member NoteProperty 'url' "http://ugc.pokevision.com/images/pokemon/$($_Pokemon.pokemonId).png"
                $_Pokemon | Add-Member NoteProperty 'scan_time' $ScanTime
                $_Pokemon | Add-Member NoteProperty 'scan_TimeRounded' $ScanTimeRounded
                $_Pokemon | Add-Member NoteProperty 'scan_latitude' $ScanningLat
                $_Pokemon | Add-Member NoteProperty 'scan_longitude' $ScanningLong
                #$_Pokemon | Add-Member NoteProperty 'scan_place' $ScanAddress
                #$_Pokemon | Add-Member NoteProperty 'scan_neighborhood' $ScanNeighborhood
                #$_Pokemon | Add-Member NoteProperty 'neighborhood' $PokemonNeighborhood
                #$_Pokemon | Add-Member NoteProperty 'place' $PokemonPlace
                $_Pokemon | Add-Member NoteProperty 'name' $pokemonHT.($_Pokemon.pokemonId)
                $ScanTable.Add($_Pokemon.id, $_Pokemon)
                $Page.Add($_Pokemon) | Out-Null
            }
        }
    }
    if($Page -as [bool])
    {
        $FileName = "C:\Page$($i)-$($StartTime).json"
        @{ 
            'id' = "$($i -as [string])-$($StartTime)"
            'scanValue' = $Page
        } | ConvertTo-JSON -Depth ([int]::MaxValue) > $FileName

        Add-DocDBDocument -Path $FileName -DatabaseName 'pokemon_location' -CollectionName 'minneapolis' -Context $DocDBContext | Out-Null
        Remove-Item $FileName
    }
}
