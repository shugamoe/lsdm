# Julian McClellan
# HW1: Par Kmeans
# Large Scale Data Methods | Winter 2018

# Note to keep "Country_Mortgage_Funding.csv" in same working directory!

from multiprocessing import Process, cpu_count, Pipe, Lock
from scipy.spatial.distance import cdist as distance
import pandas as pd
import numpy as np
import pdb

def par_kmeans(k, procs, max_iters=100, seed=117, data=None):
    """
    Parallelizable function that writes the given data with a new column
    "cluster_id"

    Args:

    (int) k: Number of proposed clusters in the data
    (int) procs: Number of processes (processors) to use
    (int) max_iters: Maximum number of iterations for centroids until stopping
    (int) seed: Random seed number
    (pd.DataFrame or None) data: The data to run kmeans clustering on.
        Note that not much is done to accomodate datasets other than
        Country_Mortgage_Funding.csv

    Initial assignments are randomly selected from the data. Convergence occurs
    when the cluster_id assignments do not change or when a certain number of
    iterations is reached.

    Returns:
        (list): Index 0 is the centroids, index 1 is the original data with a
        column of cluster_ids appended
    """
    if cpu_count() < procs:
        print("Warning: Utilizing more processes than CPU's available on this"
                " computer.")

    # Get default mortgage data
    if data is None:
        data = pd.read_csv("Country_Mortgage_Funding.csv", index_col=0)

    # Sanity Checks
    if k > len(data):
        raise Exception("Cannot have more clusters than observations.")
    if max_iters <= 1:
        raise Exception("You should really have at least 2 iterations.")

    # Initialize random centroids from data
    initial_centroids = np.array(data.loc[np.random.choice(data.index, k, replace=False)])

    # Extract index of data, shuffle it
    data_index = np.array(data.index)
    np.random.shuffle(data_index)

    # Iterate
    def iterate(initial_centroids):
        convergence = False
        num_iters = 0
        data_index_splits = np.array_split(data_index, procs) # Divide data among processes

        def calc_cluster_id(data_slice, cur_centroids):
            """
            This nested function finds the closest centroids to the slice of data its given.

            Args:

            (pd.DataFrame) data_slice: Some or all of the original data
            (np.ndarray) cur_centroids: The vectors identifying the current centroids
            """
            # Calculate the euclidean norm from all points in data slice to each centroid
            # Take advantage of numpy broadcasting to vectorize norm calculation
            all_dists = np.linalg.norm(np.array(data_slice)[:, np.newaxis] - cur_centroids, axis=2)

            # Find the index of the centroid with the smallest distance.
            return np.vstack([np.array(data_slice.index), all_dists.argmin(axis=1)])

        def multi_proc_kmeans(data_slice, receive_centroids_conn, id_send_conn):
            """
            This function continuosly checks the processes pipe's for new
            centroids, and returns the cluster ids it calculates given its
            share of the data and the centroids.

            This implementation, together with pipes, guarantees that the
            expensive process of killing and restarting a process need not
            occur.

            (pd.DataFrame) data_slice: Some or all of the original data
            (Pipe) receive_centroids_conn: Pipe to receive centroid data from
            (Pipe) id_send_conn: Pipe to send cluster id data
            """
            while True:
                # Receive new centroids from pipe
                cur_centroids = receive_centroids_conn.recv()

                # Use pipe to send cluster_id inferred from min distances
                id_send_conn.send(calc_cluster_id(data_slice, cur_centroids))

        if procs > 1:
            # Set up the processes with Pipe objects so they do not have to close between iterations
            centroid_sending, id_receiving, processes = [], [], []
            for index_split in data_index_splits:
                # For each processes create the requisite pipes for sending/receiving
                # data concerning the centroid locations and the id clusters
                centroid_send, centroid_receive, id_send, id_receive = *Pipe(), *Pipe()
                p = Process(target=multi_proc_kmeans,
                        args=(data.loc[index_split], centroid_receive,
                            id_send))

                centroid_sending.append(centroid_send)
                id_receiving.append(id_receive)
                processes.append(p)

            # Start processes
            _ = [p.start() for p in processes]


        working_centroids = initial_centroids # We first send the initial centroids
        while not convergence:
            num_iters += 1
            result = [] 
            if procs > 1: # Use mp if more than 1 proc specified
                for centroid_pipe, id_pipe in zip(centroid_sending, id_receiving):
                    # Send each process the centroid coordinates
                    centroid_pipe.send(working_centroids)

                # Receive the results of the individual processes
                _ = [result.append(id_pipe.recv()) for id_pipe in id_receiving]

                # Structure the results in a way that makes calculation of new
                # centroids convenient
                result = np.vstack([np.transpose(ids_indices) for ids_indices in result])
            else: # Otherwise do not use multiple processes
                result = np.transpose(calc_cluster_id(data.loc[:, data.columns !=
                    "cluster_id"], working_centroids))

            # Give results same ordering as dataframe
            result.sort(axis=0)

            # Check for convergence (no cluster_id changes or max_iters
            # reached)
            # Determine how many cluster_ids changed
            if num_iters > 1:
                ids_changed = len(np.where(np.array(data["cluster_id"]) !=
                    result[:, 1])[0])
            else:
                ids_changed = None # On the first iteration no IDs "change" per se

            # Update to the latest cluster ids
            data["cluster_id"] = result[:, 1]

            if num_iters == max_iters or ids_changed == 0:
                convergence = True
                print("Convergence reached at {}/{} iterations\n".format(num_iters, max_iters))

                # End processes if there were multiple
                if procs > 1:
                    _ = [p.terminate() for p in processes]
                    _ = [p.join() for p in processes]
            else:
                # Initialize centroids for next iteration 
                working_centroids = np.array(data.groupby("cluster_id").mean())

        file_name = "Country_Mortgage_Funding_{}_clusters.csv".format(k)
        data.to_csv(file_name)
        print("File written ({})".format(file_name))
        return [data, working_centroids]

    return iterate(initial_centroids)
