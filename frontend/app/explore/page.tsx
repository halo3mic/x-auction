"use client";

import { useState } from "react";

import { SecretAuctionCard } from "@/components/SecretAuctionCard";
import { mockSecrets } from "@/mocks/secretsMock";

export default function ExplorePage() {
  const [secrets, setSecrets] = useState(mockSecrets);

  // useEffect(() => {
  //   Fetch secrets from API
  //   setSecrets(fetchedSecrets)
  // }, [])

  return (
    <div className="container mx-auto py-12">
      <h1 className="text-4xl font-bold mb-8 text-center">Explore Secrets</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
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
