"use client";

import { Globe, User } from "lucide-react";
import { useEffect, useState } from "react";

import { SecretAuctionCard } from "@/components/SecretAuctionCard";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { mockSecrets } from "@/mocks/secretsMock";

export default function ExplorePage() {
  const [allSecrets, setAllSecrets] = useState(mockSecrets);
  const [mySecrets, setMySecrets] = useState(
    mockSecrets.filter((secret) => secret.userBid),
  );
  const [selectedView, setSelectedView] = useState("all");

  useEffect(() => {
    // Fetch logic here (commented out)
  }, []);

  return (
    <div className="container mx-auto py-8 px-4 sm:py-12 sm:px-6 lg:px-8">
      <h1 className="text-3xl sm:text-4xl font-bold mb-8 text-center">
        Explore Secrets
      </h1>

      <ToggleGroup
        type="single"
        value={selectedView}
        onValueChange={setSelectedView}
        className="justify-center mb-6"
      >
        <ToggleGroupItem value="all" aria-label="All Auctions">
          <Globe className="w-4 h-4 mr-2" />
          All Auctions
        </ToggleGroupItem>
        <ToggleGroupItem value="my" aria-label="My Auctions">
          <User className="w-4 h-4 mr-2" />
          My Auctions
        </ToggleGroupItem>
      </ToggleGroup>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {(selectedView === "all" ? allSecrets : mySecrets).map((secret) => (
          <SecretAuctionCard key={secret.id} {...secret} />
        ))}
      </div>
    </div>
  );
}
