defmodule GuitarBot.Service.TabScraper do
  require Logger

  def get_song(text, version_number) do
    # TODO sanitize text
    with {:ok, matches_list} <- search_song(text),
         {:ok, name, band, versions_list} <- get_best_match_data(matches_list),
         {:ok, song_text, version_number} <- get_best_version(versions_list, version_number),
         # {:ok, chords} <- get_chords(song_text),
         {:ok, pdf_path} <- generate_pdf(name, band, song_text),
         do: {:ok, %{name: name, band: band, pdf_path: pdf_path, version_number: version_number}}
  end
  # 911tabs Methods

  # For inline search
  def search_text(text) do
    url = "http://www.911tabs.com/search.php?search=#{text}"
    case HTTPotion.get("#{url}", timeout: 5_000, follow_redirects: true) do
      %HTTPotion.Response{ body: body, status_code: 200 } ->
        results = body
        |> Floki.find("div.line")
        |> Enum.map(fn(item) ->
          item = item
          |> Floki.raw_html
          |> String.replace("</b><b>", "</b>&#32;<b>") # Exact matches don't have spaces
          name = simple_floki_get_text(".song.name", item)
          band = simple_floki_get_text(".band.name", item)
          # Unify code attempt. It gets very slow.
          # link = item
          # |> Floki.find(".song.name")
          # |> Floki.attribute("href")
          # |> Enum.at(0)
          # |> String.replace(~r/\/([a-z|_]*)_tab.htm/, "/guitar_tabs/\\g{1}_guitar_tab.htm")
          # |> String.replace_prefix("", "http://www.911tabs.com")
          %{band: band, name: name}
        end)
        {:ok, results}
      response ->
        # Logger.error "[911tabs search] \"#{url}\" - #{inspect response}"
        {:error, response}
    end
  end

  # For normal search
  defp search_song(text) do
    url = "http://www.911tabs.com/search.php?search=#{text}"
    case HTTPotion.get("#{url}", timeout: 5_000, follow_redirects: true) do
      %HTTPotion.Response{ body: body, status_code: 200 } ->
        matches_list = Floki.find(body, ".line>.song.name")
        |> Enum.map(fn({_tag_name, attributes, _children_nodes}) ->
          attributes
          |> Enum.into(%{})
          |> Map.get("href")
          |> String.replace(~r/\/([a-z|_]*)_tab.htm/, "/guitar_tabs/\\g{1}_guitar_tab.htm")
          |> String.replace_prefix("", "http://www.911tabs.com")
        end)
        case Enum.count(matches_list) > 0 do
          true ->
            {:ok, matches_list}
          false ->
            {:error, :no_results}
        end
      response ->
        # Logger.error "[911tabs search] \"#{url}\" - #{inspect response}"
        {:error, response}
    end
  end

  defp get_best_match_data(matches_list) do
    url = matches_list |> Enum.at(0) # First match / Best match
    case HTTPotion.get("#{url}", timeout: 5_000, follow_redirects: true) do
      %HTTPotion.Response{ body: body, status_code: 200 } ->
        name = simple_floki_get_text("[itemprop=name]", body)
        band = simple_floki_get_text("[itemprop=author]", body)

        versions_list = Floki.find(body, ".line.animated a")

        versions_urls =
        Enum.filter(versions_list, fn({_,_, children_nodes}) ->
          Floki.raw_html(children_nodes)
          |> String.contains?("type chords")
        end) # Prefers chords
        ++
        Enum.filter(versions_list, fn({_,_, children_nodes}) ->
          Floki.raw_html(children_nodes)
          |> String.contains?("type guitar")
        end)
        |> Enum.reject(fn({_,_, children_nodes}) ->
          Floki.raw_html(children_nodes)
          |> String.contains?("type guitar-pro")
        end) # Hates guitar-pro  
        |> Enum.map(fn({_tag_name, attributes, _children_nodes}) ->
          attributes
          |> Enum.into(%{})
          |> Map.get("data-url")
        end)

        # Add API results? http://www.911tabs.com/json/tabs/597/22191/1/2.json

        {:ok, name, band, versions_urls}
      response ->
        # Logger.error "[911tabs search] \"#{url}\" - #{inspect response}"
        {:error, response}
    end
  end

  defp get_best_version(list, version), do: Enum.drop(list, version) |> get_best_version_recursive(version)
  defp get_best_version_recursive([], _), do: {:error, :no_versions}
  defp get_best_version_recursive([url|tail], version) do
    case get_version(url) do
      {:ok, song_text} ->
        {:ok, song_text, version}
      _ ->
        get_best_version_recursive(tail, version + 1)
    end
  end

  defp get_version(url) do
    with {:ok, selector}  <- url |> URI.parse |> Map.get(:host) |> get_host_selector(url),
         {:ok, song_text} <- parse_site(selector, url),
         song_text        <- beautify_song_text(song_text),
         do: {:ok, song_text}
  end

  # Supported sites

  defp get_host_selector("tabs.ultimate-guitar.com", _) , do: {:ok, :ultimate_guitar}
  defp get_host_selector("www.cifraclub.com.br", _)     , do: {:ok, "pre"}
  defp get_host_selector("acordes.lacuerda.net", _)     , do: {:ok, "pre"}
  defp get_host_selector("www.guitaretab.com", _)       , do: {:ok, "body .js-tab-content"}
  defp get_host_selector("www.tabcrawler.com", _)       , do: {:ok, "pre"}
  defp get_host_selector("www.guitartabs.cc", _)        , do: {:ok, "body .tabcont font pre"}
  defp get_host_selector("www.tabondant.com", _)        , do: {:ok, "pre"}
  defp get_host_selector("tabs-database.com", _)        , do: {:ok, "pre"}
  defp get_host_selector("www.e-chords.com", _)         , do: {:ok, "pre#core"}
  defp get_host_selector("www.azchords.com", _)         , do: {:ok, "body #content"}
  defp get_host_selector("tablatures.tk", _)            , do: {:ok, "div.text"}
  defp get_host_selector("www.ttabs.com", _)            , do: {:ok, "pre"}
  defp get_host_selector(host, url)                     , do: {:error, "Unsupported site #{inspect host} - #{inspect url}"}

  defp parse_site(:ultimate_guitar, url) do
    case HTTPotion.get("#{url}", timeout: 5_000, follow_redirects: true) do
      %HTTPotion.Response{ body: body, status_code: 200 } ->
        {_, _, [script_tag_content]} = body
        |> Floki.find("script") 
        |> Enum.find(fn({_,_,[text]}) -> String.contains?(text,"page = ") end) 
        
        weird_json = script_tag_content
        |> String.replace_prefix("\n    window.UGAPP.store.page = ", "") 
        |> String.replace(";", "") 
        |> Poison.decode!
        
        text = weird_json["data"]["tab_view"]["wiki_tab"]["content"] 
        |> String.replace("[ch]", "") 
        |> String.replace("[/ch]", "")

        {:ok, text}
      response ->
        # Logger.error "[911tabs search] \"#{url}\" - #{inspect response}"
        {:error, response}        
    end
  end
  defp parse_site(selector, url) do
    url = url |> String.split("#") |> Enum.at(0)
    case HTTPotion.get("#{url}", timeout: 5_000, follow_redirects: true) do
      %HTTPotion.Response{ body: body, status_code: 200 } ->
        text = simple_floki_get_text(selector, body)
        case (text |> String.split("\n") |> Enum.count) > 5 do
          true -> {:ok, text}
          false -> {:error, :useless_piece_of_garbage}
        end
      response ->
        # Logger.error "[911tabs search] \"#{url}\" - #{inspect response}"
        {:error, response}
    end
  end

  defp simple_floki_get_text(selector, body) do
    body
    |> replace_whitespaces
    |> Floki.find(selector)
    |> Floki.text
    |> String.replace(~r/(\])/, "\\g{1}\n") # Para tags de página
  end

  defp replace_whitespaces(text, last_text \\ "")
  defp replace_whitespaces(text, last_text) when last_text == text, do: text
  defp replace_whitespaces(text, _) do
    text
    |> String.replace(~r/>((&#32;)*) ( *)</, ">\\g{1}&#32;\\g{3}<")
    |> replace_whitespaces(text)
  end

  defp beautify_song_text(song_text) do
    song_text
    |> String.replace("\n\r", "\n")
    |> String.replace("\r\n", "\n")
    |> remove_extra_breaks
    |> String.replace("\n", "\n\r")
  end

  defp remove_extra_breaks(text, last_text \\ "")
  defp remove_extra_breaks(text, last_text) when last_text == text, do: text
  defp remove_extra_breaks(text, _) do
    text
    |> String.replace("\n\n\n", "\n\n")
    |> String.replace("\n\n\n\n", "\n\n")
    |> remove_extra_breaks(text)
  end

  defp generate_pdf(name, band, song_text) do
    """
    <pre style="font-size:10px;line-height: .7;">
    #{band} - #{name}

    #{song_text}
    </pre>
    """
    |> PdfGenerator.generate(filename: "#{band} - #{name}")
  end


end
