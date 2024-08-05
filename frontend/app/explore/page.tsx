"use client";

import { Globe, User } from "lucide-react";
import { useEffect, useState } from "react";

import { SecretAuctionCard } from "@/components/SecretAuctionCard";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { mockSecrets } from "@/mocks/secretsMock";

export default function ExplorePage() {
  const [allSecrets, setAllSecrets] = useState(mockSecrets);
  const [mySecrets, setMySecrets] = useState(
    mockSecrets.filter((secret) => secret.userBid),
  );
  const [activeTab, setActiveTab] = useState("all");

  useEffect(() => {
    // Fetch logic here (commented out)
  }, []);

  const secrets = activeTab === "all" ? allSecrets : mySecrets;

  return (
    <div className="container mx-auto py-8 px-4 sm:py-12 sm:px-6 lg:px-8">
      <h1 className="text-3xl sm:text-4xl font-bold mb-6 sm:mb-8 text-center">
        Explore Secrets
      </h1>

      <Tabs
        value={activeTab}
        onValueChange={setActiveTab}
        className="w-full mb-6 sm:mb-8"
      >
        <TabsList className="grid w-full max-w-md grid-cols-2 mx-auto h-12">
          <TabsTrigger
            value="all"
            className="flex items-center justify-center gap-2 text-base font-medium transition-all duration-200 ease-in-out data-[state=active]:bg-primary/10 data-[state=active]:text-primary hover:bg-muted/80"
          >
            <Globe className="w-5 h-5" />
            All Auctions
          </TabsTrigger>
          <TabsTrigger
            value="my"
            className="flex items-center justify-center gap-2 text-base font-medium transition-all duration-200 ease-in-out data-[state=active]:bg-primary/10 data-[state=active]:text-primary hover:bg-muted/80"
          >
            <User className="w-5 h-5" />
            My Auctions
          </TabsTrigger>
        </TabsList>
      </Tabs>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6 lg:gap-8">
        {secrets.map((secret) => (
          <SecretAuctionCard
            key={secret.id}
            id={secret.id}
            description={secret.description}
            userBid={secret.userBid}
            endTime={secret.endTime}
          />
        ))}
      </div>
    </div>
  );
}
