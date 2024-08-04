"use client";

import { useState, useEffect } from "react";
import {
	Card,
	CardHeader,
	CardTitle,
	CardContent,
	CardFooter,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { BookLock, Clock, ArrowRight, User } from "lucide-react";
import Link from "next/link";
import Countdown from "react-countdown";

// Mock data for secrets (replace with actual API call later)
const mockSecrets = [
	{
		id: 1,
		description: "Insider scoop on Ethereum's next major upgrade",
		currentBid: 1.5,
		endTime: Date.now() + 3 * 24 * 60 * 60 * 1000,
		userBid: 1.6,
	},
	{
		id: 2,
		description: "Crypto x AI ideas that are actually not bullshit",
		currentBid: 2.0,
		endTime: Date.now() + 2 * 24 * 60 * 60 * 1000,
		userBid: null,
	},
	{
		id: 3,
		description: "Gary Gensler's secret crypto portfolio",
		currentBid: 3.2,
		endTime: Date.now() + 4 * 24 * 60 * 60 * 1000,
		userBid: 3.5,
	},
];

export default function ExplorePage() {
	const [secrets, setSecrets] = useState(mockSecrets);

	// useEffect(() => {
	//   // Fetch secrets from API
	//   // setSecrets(fetchedSecrets)
	// }, [])

	return (
		<div className="container mx-auto py-12">
			<h1 className="text-4xl font-bold mb-8 text-center">Explore Secrets</h1>
			<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
				{secrets.map((secret) => (
					<Card
						key={secret.id}
						className="flex flex-col hover:shadow-lg transition-all duration-300 bg-secondary/30"
					>
						<CardHeader className="pb-2">
							<CardTitle className="flex items-center text-2xl font-bold">
								<BookLock className="text-primary mr-3" size={28} />
								Secret #{secret.id}
							</CardTitle>
						</CardHeader>
						<CardContent className="flex-grow pt-4">
							<p className="text-muted-foreground mb-6 line-clamp-2 text-sm">
								{secret.description}
							</p>
							<div className="flex justify-between items-end">
								<div>
									<p className="text-xs font-medium text-muted-foreground mb-1">
										Your Bid
									</p>
									{secret.userBid ? (
										<p className="text-2xl font-bold text-primary flex items-center">
											<User className="mr-2" size={20} />
											{secret.userBid} ETH
										</p>
									) : (
										<p className="text-sm font-semibold text-muted-foreground">
											No bid placed
										</p>
									)}
								</div>
								<div className="text-right">
									<p className="text-xs font-medium text-muted-foreground mb-1">
										Ends in
									</p>
									<p className="text-sm font-semibold flex items-center justify-end bg-primary/10 rounded-full px-3 py-1">
										<Clock className="mr-1 text-primary" size={14} />
										<Countdown
											date={secret.endTime}
											renderer={({ days, hours, minutes }) => (
												<span className="text-primary font-bold">
													{days}d {hours}h {minutes}m
												</span>
											)}
										/>
									</p>
								</div>
							</div>
						</CardContent>
						<CardFooter className="pt-4">
							<Link href={`/bid/${secret.id}`} className="w-full">
								<Button className="w-full group" size="lg">
									<span>{secret.userBid ? "Update Bid" : "Place Bid"}</span>
									<ArrowRight
										className="ml-2 group-hover:translate-x-1 transition-transform"
										size={18}
									/>
								</Button>
							</Link>
						</CardFooter>
					</Card>
				))}
			</div>
		</div>
	);
}
