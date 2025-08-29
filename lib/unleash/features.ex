defmodule Unleash.Features do
  @moduledoc false

  alias Unleash.Feature

  @derive Jason.Encoder
  defstruct version: "2", features: []

  def from_map!(%{"version" => version, "features" => features}) do
    %__MODULE__{
      version: version,
      features: Enum.map(features, &Feature.from_map/1)
    }
  end

  def from_map!(_) do
    raise ArgumentError, "failed to construct state"
  end

  def from_map(%{"version" => version, "features" => features}) do
    {:ok,
     %__MODULE__{
       version: version,
       features: Enum.map(features, &Feature.from_map/1)
     }}
  end

  def from_map(_), do: {:error, "failed to construct state"}

  def from_list!(features, version \\ 2) do
    %__MODULE__{
      version: version,
      features: features
    }
  end

  def get_feature(nil, _feat), do: nil

  def get_feature(%__MODULE__{features: nil}, _feature), do: nil

  def get_feature(%__MODULE__{}, nil), do: nil

  def get_feature(%__MODULE__{features: features} = state, feat)
      when is_list(features) and is_atom(feat),
      do: get_feature(state, Atom.to_string(feat))

  def get_feature(%__MODULE__{features: features}, feat)
      when is_list(features) and is_binary(feat) do
    features
    |> Enum.find(fn feature -> compare(feature.name, feat) end)
  end

  def get_all_feature_names(nil), do: []

  def get_all_feature_names(%__MODULE__{features: nil}), do: []

  def get_all_feature_names(%__MODULE__{features: features}) do
    Enum.map(features, fn %Feature{name: name} ->
      name
    end)
  end

  defp compare(n1, n2), do: String.downcase(n1) == String.downcase(n2)
end
